import SwiftUI
import ReclaimKit

/// Screen 5. THE COUNT GOES UP, NEVER DOWN.
///
/// The app has no roster of who's at the table — only a list of who joined — so
/// it can show presence but never absence. Naming who hasn't put their phone
/// down yet would be both impossible and the exact nagging instrument this
/// product exists to replace.
struct CountUpView: View {
    @Environment(AppState.self) private var state
    let onwards: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: state.placeName ?? t("docked.where.unnamed"),
                    mark: Palette.clay, tint: Palette.muted)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 36) {
                Text(t("countup.headline"))
                    .font(Type.display(42)).foregroundStyle(Palette.ink)

                VStack(alignment: .leading, spacing: 24) {
                    // Left-aligned and growing, so the row obviously has room.
                    // No empty slots: an empty slot is a name you don't have.
                    HStack(spacing: 16) {
                        ForEach(state.members) { member in
                            PhoneSlab(name: member.displayName ?? "Someone",
                                      isMe: member.profileId == state.profile?.id,
                                      isDown: member.profileId == state.profile?.id
                                              ? state.iAmFaceDown : member.stillLive)
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: state.members)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("countup.count", "count", Say.count(state.members.count)))
                            .font(Type.display(28)).foregroundStyle(Palette.ink)
                        Text(t("countup.body"))
                            .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(3)
                    }
                }
            }

            Spacer(minLength: 24)

            VStack(spacing: 18) {
                Text(t("countup.footer"))
                    .font(Type.note).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                QuietButton(title: t("countup.leave"), night: false, action: onwards)
            }
        }
        .ground()
        .task {
            await state.refreshMembers()
            try? await Task.sleep(for: .seconds(8))
            onwards()
        }
    }
}

#Preview {
    CountUpView(onwards: {}).environment(AppState(repo: PreviewRepository()))
}
