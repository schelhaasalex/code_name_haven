import SwiftUI
import ReclaimKit

/// After accepting an invite: where you're in, and who asked. Nothing has
/// started, and the screen says so — the evening begins when someone sets
/// their phone down, not when a link was tapped.
struct JoinedPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    let joined: InviteAcceptance

    private var place: String { joined.placeName ?? t("joined.unnamed") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("joined.eyebrow"))
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 20) {
                Text(joined.invitedBy.map { t("joined.title", "place", place, "name", $0) }
                     ?? t("joined.title.solo", "place", place))
                    .font(Type.hero).foregroundStyle(Palette.ink)
                Text(t("joined.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            }
            Spacer(minLength: 24)
            PrimaryButton(title: t("joined.done")) { dismiss() }
        }
        .ground()
    }
}

#Preview {
    JoinedPlaceView(joined: InviteAcceptance(placeId: UUID(), placeName: "The Kitchen Table",
                                             invitedBy: "Maya"))
}
