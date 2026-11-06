import SwiftUI
import ReclaimKit

/// Screen 16. Deliberately thin: the box's name, and the way out. "How it
/// works" states the rules as facts rather than offering them as dials,
/// because a household tuning its own minimum is setup by another name.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var name = ""
    @State private var confirmingForget = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(t("settings.title")).font(Type.title).foregroundStyle(Palette.ink)

                if state.box != nil { boxSection }

                LabelledSection(label: t("settings.how.label")) {
                    ForEach(1...3, id: \.self) { i in
                        Text(t("settings.how.\(i)"))
                            .font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
                    }
                }

                LabelledSection(label: t("settings.see.label")) {
                    Text(t("settings.see.body"))
                        .font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
                }

                Spacer(minLength: 20)

                // App Store guideline 5.1.1(v) — deletion must be in-app, and
                // easy to find. It needn't be loud: the weight, and the colour,
                // belong to the confirmation that follows.
                Button { confirmingDelete = true } label: {
                    Text(t("settings.delete"))
                        .font(Type.note).foregroundStyle(Palette.muted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { name = state.box?.name ?? "" }
        .confirmationDialog(t("settings.forget"), isPresented: $confirmingForget) {
            Button(t("settings.forget"), role: .destructive) { state.forgetBox() }
        } message: {
            Text(t("settings.forget.body"))
        }
        .confirmationDialog(t("settings.delete"), isPresented: $confirmingDelete) {
            Button(t("settings.delete"), role: .destructive) {
                Task { await state.deleteAccount() }
            }
        } message: {
            Text(t("settings.delete.body"))
        }
    }

    /// Only whoever first read the box can name it; everyone else sees the
    /// name it has.
    private var boxSection: some View {
        LabelledSection(label: t("settings.box.label")) {
            if state.canRenameBox {
                TextField(t("box.unnamed"), text: $name)
                    .font(Type.body(16)).foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task { await state.renameBox(to: trimmed) }
                    }
                    .paperCard()
            } else {
                Text(state.box?.name ?? t("box.unnamed"))
                    .font(Type.body(16)).foregroundStyle(Palette.ink)
            }
            TextAction(title: t("settings.forget"), tint: Palette.ink2) { confirmingForget = true }
        }
    }
}

#Preview {
    let state = AppState(repo: PreviewRepository(), boxPlace: PreviewRepository.kitchenTable)
    return NavigationStack { SettingsView() }.environment(state).task { await state.load() }
}
