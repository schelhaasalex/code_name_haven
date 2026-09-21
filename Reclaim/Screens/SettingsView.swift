import SwiftUI
import ReclaimKit

/// Screen 16. Deliberately thin. Exactly ONE control — the rest is information
/// or an exit. "How it works" states the rules as facts rather than offering
/// them as dials, because a household tuning its own minimum is setup by
/// another name.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var nudge = true
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("settings.title")).font(Type.title).foregroundStyle(Palette.ink)
                    Text(t("settings.account", "name", state.profile?.displayName ?? "—"))
                        .font(Type.body(15)).foregroundStyle(Palette.muted)
                }

                Toggle(isOn: $nudge) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("settings.nudge.title"))
                            .font(Type.body(16, weight: .medium)).foregroundStyle(Palette.ink)
                        Text(t("settings.nudge.body", "time", "7:00pm"))
                            .font(Type.note).foregroundStyle(Palette.muted)
                    }
                }
                .tint(Palette.ink)
                .paperCard()
                .onChange(of: nudge) { _, on in
                    Task {
                        try? await state.repo.updateProfile(nudgeEnabled: on,
                                                            nudgeHour: state.profile?.nudgeHour ?? 19)
                        await Notifications.reschedule(for: state.profile)
                    }
                }

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

                VStack(alignment: .leading, spacing: 4) {
                    TextAction(title: t("settings.signout"), tint: Palette.ink2) {
                        Task { try? await (state.repo as? SupabaseRepository)?.client.auth.signOut() }
                    }

                    // App Store guideline 5.1.1(v) — deletion must be in-app.
                    Button { confirmingDelete = true } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("settings.delete"))
                                .font(Type.body(16, weight: .medium)).foregroundStyle(Palette.clayDeep)
                            Text(t("settings.delete.body"))
                                .font(Type.note).foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(minHeight: 48)
                }
                .padding(.top, 18)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { nudge = state.profile?.nudgeEnabled ?? true }
        .confirmationDialog(t("settings.delete"), isPresented: $confirmingDelete) {
            Button(t("settings.delete"), role: .destructive) {
                Task { try? await state.repo.deleteAccount(); await state.load() }
            }
        } message: {
            Text(t("settings.delete.body"))
        }
    }

}

#Preview {
    NavigationStack { SettingsView() }.environment(AppState(repo: PreviewRepository()))
}
