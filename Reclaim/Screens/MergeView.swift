import SwiftUI
import ReclaimKit

/// Folding two places into one — the fix for the same table getting scanned
/// twice and becoming "The Kitchen Table" and "quiet-heron".
///
/// The folded-away place is kept rather than deleted, so a card already printed
/// and stuck to a fridge still resolves to the survivor. Nothing a person has
/// put on their wall stops working because of something they did in an app.
struct MergeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var from: Place?
    @State private var into: Place?
    @State private var merging = false

    private var ready: Bool { from != nil && into != nil && from?.id != into?.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: t("merge.eyebrow"))
                Text(t("merge.headline"))
                    .font(Type.title).foregroundStyle(Palette.ink)
                Text(t("merge.body"))
                    .font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)

                picker(label: t("merge.from"), selection: $from, excluding: into)
                picker(label: t("merge.into"), selection: $into, excluding: from)

                actions
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
    }

    private func picker(label: String, selection: Binding<Place?>, excluding: Place?) -> some View {
        LabelledSection(label: label, spacing: 8) {
            ForEach(state.places.filter { $0.id != excluding?.id }) { place in
                Button { selection.wrappedValue = place } label: {
                    row(place, chosen: selection.wrappedValue?.id == place.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ place: Place, chosen: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name ?? Handle.pretty(place.handle))
                    .font(Type.body(16, weight: .medium)).foregroundStyle(Palette.ink)
                Text(Handle.pretty(place.handle))
                    .font(Type.note).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19))
                .foregroundStyle(chosen ? Palette.clay : Palette.hairline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(chosen ? Palette.clay : Palette.line, lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: t("merge.primary"), action: merge)
                .opacity(ready && !merging ? 1 : 0.4)
                .disabled(!ready || merging)
            QuietButton(title: t("merge.cancel")) { dismiss() }
        }
    }

    private func merge() {
        guard let from, let into, ready, !merging else { return }
        merging = true
        // @MainActor explicitly: `banner` belongs to a main-actor class, and a
        // plain Task here inherits nothing to say so.
        Task { @MainActor in
            await state.merge(from, into: into)
            state.banner = t("merge.done")
            dismiss()
        }
    }
}

#Preview {
    MergeView().environment(AppState(repo: PreviewRepository()))
}
