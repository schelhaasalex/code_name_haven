import SwiftUI
import ReclaimKit

/// Screen 17. Live first — the one thing worth interrupting for.
struct PlacesView: View {
    @Environment(AppState.self) private var state
    @State private var merging = false
    @State private var naming = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(t("places.title")).font(Type.title).foregroundStyle(Palette.ink)

                ForEach(state.places) { place in
                    NavigationLink(value: Route.place(place)) { row(place) }
                        .buttonStyle(.plain)
                }

                // Unnamed sessions are a valid, permanent state — never framed
                // as a deficiency.
                somewhere

                Spacer(minLength: 12)

                Button { merging = true } label: {
                    Label(t("places.merge"), systemImage: "arrow.triangle.merge")
                        .font(Type.body(14)).foregroundStyle(Palette.muted)
                        .frame(minHeight: 44)
                }

                Button(action: scan) {
                    Label(t("places.scan"), systemImage: "wave.3.right")
                        .font(Type.body(16, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(Palette.ink)
                        .background(Palette.paper, in: Capsule())
                        .overlay { Capsule().stroke(Palette.line, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $merging) { MergeView() }
        .sheet(isPresented: $naming) { NamingView() }
    }

    /// The same URL a tag by the door would hand the system, taking the same
    /// path through `URLRouter` — so scanning in the app and tapping on the way
    /// in cannot drift apart.
    private func scan() {
        TagSession.read { url in
            Task { await URLRouter.handle(url, state: state) }
        }
    }

    @ViewBuilder private func row(_ place: Place) -> some View {
        let isLive = state.gathering?.placeId == place.id
        VStack(alignment: .leading, spacing: isLive ? 10 : 5) {
            if isLive {
                HStack(spacing: 9) {
                    Circle().fill(Palette.ember).frame(width: 8, height: 8)
                    Text(t("places.live.label")).eyebrow(Palette.ember)
                }
            }
            Text(place.name ?? Handle.pretty(place.handle))
                .font(Type.display(isLive ? 25 : 21))
                .foregroundStyle(isLive ? Palette.cream : Palette.ink)
            Text(Handle.pretty(place.handle))
                .font(Type.body(14))
                .foregroundStyle(isLive ? Palette.dust : Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isLive ? 20 : 16)
        .background(isLive ? Palette.ink : Palette.paper, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if !isLive { RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1) }
        }
    }

    private var somewhere: some View {
        DashedCard { HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(t("places.somewhere.title")).font(Type.display(21)).foregroundStyle(Palette.ink2)
                Text(t("places.somewhere.body",
                       "count", Say.number(state.evenings(at: nil).count)))
                    .font(Type.body(14)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(t("places.somewhere.action"))
                .font(Type.body(14, weight: .medium)).foregroundStyle(Palette.clayDeep)
        } }
    }
}

#Preview {
    NavigationStack { PlacesView() }.environment(AppState(repo: PreviewRepository()))
}
