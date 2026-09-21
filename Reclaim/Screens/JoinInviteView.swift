import SwiftUI
import ReclaimKit

/// Screen 4. Someone you know set theirs down somewhere you both know.
///
/// The only thing in this product that interrupts a person, and it can only
/// ever say that somebody ARRIVED. There is no version of this screen that
/// fires because you didn't show up.
///
/// The name comes from the invitation itself — the person who started it sent
/// their own — because until you join, the app has no way to learn anyone's
/// name, and inventing one would be the exact failure the knowledge test
/// exists to catch.
struct JoinInviteView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let invitation: Invitation

    private var placeName: String {
        state.places.first { $0.id == invitation.place }?.name
            ?? t("places.somewhere.title")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("join.eyebrow"), mark: Palette.ember, tint: Palette.dust)
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 16) {
                Text(t("join.headline",
                       "name", invitation.name ?? t("join.someone"),
                       "place", placeName))
                    .font(Type.display(40)).foregroundStyle(Palette.cream)
                    .lineSpacing(2)
                Text(t("join.body", "count", Say.number(invitation.count)))
                    .font(Type.lede).foregroundStyle(Palette.dust)
            }

            Spacer(minLength: 24)

            VStack(spacing: 10) {
                PrimaryButton(title: t("join.primary"), night: true) {
                    Task { await state.join(invitation) }
                }
                QuietButton(title: t("join.secondary"), night: true) {
                    state.dismissInvitation()
                    dismiss()
                }
            }
        }
        .ground(night: true)
    }
}

#Preview {
    JoinInviteView(invitation: Invitation(gathering: UUID(),
                                          place: PreviewRepository.kitchenTable,
                                          name: "Maya",
                                          count: 2,
                                          at: .now))
        .environment(AppState(repo: PreviewRepository()))
}
