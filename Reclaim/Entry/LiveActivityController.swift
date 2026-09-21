import Foundation
import ActivityKit
import ReclaimKit

/// Screens 7 and 19 — the pair that earn the native rewrite. Start without
/// unlocking, end without unlocking, app never opened in between.
@MainActor
enum LiveActivityController {

    private static var current: Activity<ReclaimActivityAttributes>?

    static func start(gatheringId: UUID, startedAt: Date, memberCount: Int, placeName: String?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await end()
        let state = ReclaimActivityAttributes.ContentState(
            startedAt: startedAt, memberCount: memberCount, placeName: placeName)
        current = try? Activity.request(
            attributes: ReclaimActivityAttributes(gatheringId: gatheringId),
            content: .init(state: state, staleDate: nil))
    }

    static func update(startedAt: Date, memberCount: Int, placeName: String?) async {
        guard let current else { return }
        await current.update(.init(
            state: .init(startedAt: startedAt, memberCount: memberCount, placeName: placeName),
            staleDate: nil))
    }

    static func end() async {
        guard let current else { return }
        await current.end(nil, dismissalPolicy: .immediate)
        Self.current = nil
    }
}
