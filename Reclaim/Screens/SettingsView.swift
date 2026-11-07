import SwiftUI
import ReclaimKit

/// Screen 16. Deliberately thin: the boxes' names, and the way out. "How it
/// works" states the rules as facts rather than offering them as dials,
/// because a household tuning its own minimum is setup by another name.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var forgetting: UUID?
    @State private var scanning = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(t("settings.title")).font(Type.title).foregroundStyle(Palette.ink)

                if !state.boxPlaces.isEmpty { boxSection }

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
        .fullScreenCover(isPresented: $scanning) { ScanView() }
        .confirmationDialog(t("settings.forget"),
                            isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } })) {
            Button(t("settings.forget"), role: .destructive) {
                if let id = forgetting { state.forget(id) }
            }
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

    /// Each box: only whoever first read it can name it; everyone else sees
    /// the name it has. And another box, met the way the first one was.
    private var boxSection: some View {
        LabelledSection(label: t(state.boxPlaces.count > 1 ? "settings.boxes.label" : "settings.box.label")) {
            ForEach(state.boxPlaces, id: \.self) { id in
                BoxSettings(name: state.name(of: id), canRename: state.canRename(id),
                            onRename: { name in Task { await state.rename(id, to: name) } },
                            onForget: { forgetting = id })
            }
            TextAction(title: t("settings.add"), tint: Palette.ink2, icon: "plus") { scanning = true }
        }
    }
}

#Preview {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return NavigationStack { SettingsView() }.environment(state).task { await state.load() }
}
