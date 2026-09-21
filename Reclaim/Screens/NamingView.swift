import SwiftUI
import ReclaimKit

/// Screen 21 — the only place in the product where a person is asked to name
/// anything, and it is still optional.
///
/// Two jobs, because they are the same conversation: naming the unnamed
/// history, which mints a real place and moves every "Somewhere" evening onto
/// it, and renaming a place that already has one.
///
/// The handle is drawn BEFORE you commit, not after, so the footer can tell you
/// what the card will say while you are still deciding.
struct NamingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    /// Nil means the unnamed history — naming it is what turns it into a place.
    var place: Place?

    @State private var name = ""
    @State private var minted = Handle.generate()
    @State private var saving = false

    private var handle: String { place?.handle ?? minted }
    private var evenings: Int { state.evenings(at: place?.id).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("naming.eyebrow"))
            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 22) {
                Text(t("naming.headline"))
                    .font(Type.hero).foregroundStyle(Palette.ink)
                if evenings > 1, let time = state.usualTime(at: place?.id) {
                    Text(t("naming.context",
                           "count", Say.number(evenings),
                           "time", time.shortTime))
                        .font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                }
                field
                suggestions
            }

            Spacer(minLength: 20)
            actions
        }
        .ground()
    }

    private var field: some View {
        LabelledSection(label: t("naming.label")) {
            TextField("", text: $name)
                .font(Type.display(24))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { save() }
                .paperCard()
        }
    }

    private var suggestions: some View {
        LabelledSection(label: t("naming.suggestions.label"), spacing: 8) {
            // A wrapping row of taps, because typing on a phone at a dinner
            // table is the thing most likely to end this interaction.
            FlowRow(spacing: 8) {
                ForEach(Copy.list("naming.suggestions"), id: \.self) { suggestion in
                    Button { name = suggestion } label: {
                        Text(suggestion)
                            .font(Type.body(14))
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .overlay { Capsule().stroke(Palette.line, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: t("naming.primary"), action: save)
                .opacity(name.trimmed.isEmpty || saving ? 0.4 : 1)
                .disabled(name.trimmed.isEmpty || saving)
            if place == nil {
                QuietButton(title: t("naming.skip")) { dismiss() }
            }
            Text(t("naming.footer", "handle", Handle.pretty(handle)))
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
                .padding(.top, 6)
        }
    }

    private func save() {
        let chosen = name.trimmed
        guard !chosen.isEmpty, !saving else { return }
        saving = true
        Task {
            if let place {
                await state.rename(place, to: chosen)
            } else {
                await state.nameSomewhere(chosen, handle: minted)
            }
            dismiss()
        }
    }
}

#Preview("Somewhere") {
    NamingView().environment(AppState(repo: PreviewRepository()))
}

#Preview("Rename") {
    NamingView(place: Place(id: UUID(), name: "The Deck", handle: "calm-badger"))
        .environment(AppState(repo: PreviewRepository()))
}
