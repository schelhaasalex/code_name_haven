import Foundation
import ReclaimKit

/// The one evening nudge: asked for once, then scheduled from `NudgePlan` —
/// at your usual time when there is one, never on a day you've already set it
/// down, and fading to nothing if you drift away.
@MainActor
extension AppState {

    /// Screen 8's question, and the Settings toggle. Asks the system only on a
    /// yes, and keeps the local profile in step — the toggle used to save the
    /// change and then schedule from the profile as it was before.
    public func setNudge(on: Bool) async {
        guard var p = profile else { return }
        try? await repo.updateProfile(nudgeEnabled: on, nudgeHour: p.nudgeHour)
        p.nudgeEnabled = on
        profile = p
        if on, await Notifications.canOffer() { await Notifications.ask() }
        await rescheduleNudges()
    }

    /// The next few weeks of nudges, from what the app knows now. Your usual
    /// place, when there is one, is what the nudge offers.
    func rescheduleNudges() async {
        guard let p = profile, p.nudgeEnabled else {
            await Notifications.clear()
            return
        }
        let plan = NudgePlan.upcoming(
            starts: recent.filter(\.qualifying).map(\.startedAt),
            // Any evening, however short, starts the fade again.
            lastEvening: recent.map(\.startedAt).max(),
            hour: p.nudgeHour,
            live: isLive)
        let body = usualPlace?.name.map { t("notification.nudge.place", "place", $0) }
            ?? t("notification.nudge")
        await Notifications.schedule(plan, body: body)
    }
}
