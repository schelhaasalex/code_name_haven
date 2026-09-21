import SwiftUI
import ReclaimKit

/// "Where is this?", asked after the phone is already down — from the docked
/// screen, or the session screen for as long as the evening has no place.
///
/// Never a race and never required: Somewhere counts exactly the same, and
/// leaving is as easy as choosing. Scanning the card is how a first-time guest
/// gets in; picking a place is for somewhere you've been, where the card is
/// across the room.
struct WhereSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    /// Your places, less the one this evening is already at.
    private var elsewhere: [Place] {
        state.places.filter { $0.id != state.gathering?.placeId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("docked.where.label"), mark: Palette.ember, tint: Palette.dust)

            VStack(alignment: .leading, spacing: 12) {
                Text(t("where.title")).font(Type.display(34)).foregroundStyle(Palette.cream)
                Text(t("where.body")).font(Type.lede).foregroundStyle(Palette.dust).lineSpacing(4)
            }
            .padding(.top, 28)

            Group {
                if TagSession.canRead {
                    QuietButton(title: t("docked.scan"), night: true, action: scan)
                } else {
                    Text(t("where.scan.unavailable")).font(Type.note).foregroundStyle(Palette.dim)
                }
            }
            .padding(.top, 24)

            if !elsewhere.isEmpty {
                Text(t("where.places")).eyebrow(Palette.dust).padding(.top, 32).padding(.bottom, 12)
                ScrollView {
                    NightCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(elsewhere) { place in row(place) }
                        }
                    }
                }
            }

            Spacer(minLength: 16)
            TextAction(title: t("where.stay"), tint: Palette.dust) { dismiss() }
        }
        .ground(night: true)
    }

    private func row(_ place: Place) -> some View {
        Button { choose(place.id) } label: {
            HStack {
                Text(place.name ?? place.handle)
                    .font(Type.body(16, weight: .medium)).foregroundStyle(Palette.cream)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Palette.dim)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose(_ place: UUID) {
        dismiss()
        Task { await state.moveHere(place) }
    }

    /// The same path as a card tapped on the way in: `URLRouter`, which sees
    /// the evening is already running and moves it rather than starting one.
    private func scan() {
        dismiss()
        TagSession.read { url in
            Task { await URLRouter.handle(url, state: state) }
        }
    }
}

#Preview {
    WhereSheet().environment(AppState(repo: PreviewRepository()))
}
