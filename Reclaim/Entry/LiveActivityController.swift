import Foundation
import ActivityKit
import ReclaimKit

/// Screens 7 and 19 — the pair that earn the native rewrite. Start without
/// unlocking, end without unlocking, app never opened in between.
@MainActor
enum LiveActivityController {

    private static var current: Activity<ReclaimActivityAttributes>?

    /// Reuses the activity already showing for this gathering, if the app was
    /// relaunched under it, rather than ending it and starting an identical one.
    static func start(gatheringId: UUID, startedAt: Date, memberCount: Int, placeName: String?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = ReclaimActivityAttributes.ContentState(
            startedAt: startedAt, memberCount: memberCount, placeName: placeName)
        if let running = Activity<ReclaimActivityAttributes>.activities
            .first(where: { $0.attributes.gatheringId == gatheringId }) {
            current = running
            await running.update(.init(state: state, staleDate: nil))
            return
        }
        await end()
        current = try? Activity.request(
            attributes: ReclaimActivityAttributes(gatheringId: gatheringId),
            content: .init(state: state, staleDate: nil))
    }

    static func update(startedAt: Date, memberCount: Int, placeName: String?) async {
        guard let current = current ?? Activity<ReclaimActivityAttributes>.activities.first
        else { return }
        Self.current = current
        await current.update(.init(
            state: .init(startedAt: startedAt, memberCount: memberCount, placeName: placeName),
            staleDate: nil))
    }

    /// Every activity, not just the one this launch remembers. The End button
    /// relaunches the app in the background with no memory of the activity it
    /// is ending — ending only `current` left it on the lock screen, counting
    /// up for an evening that was over.
    static func end() async {
        for activity in Activity<ReclaimActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        current = nil
    }
}
