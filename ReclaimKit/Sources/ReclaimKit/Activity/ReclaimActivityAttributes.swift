import Foundation
import ActivityKit

/// The Live Activity — screens 7 and 19, and the reason the deployment target
/// is iOS 17: an interactive End button on a Live Activity needs App Intents in
/// widgets. Before 17 a Live Activity could only be looked at, and ending meant
/// unlocking the phone you had just put down.
public struct ReclaimActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startedAt: Date
        public var memberCount: Int
        /// nil renders as "Somewhere", and counts exactly the same.
        public var placeName: String?

        public init(startedAt: Date, memberCount: Int, placeName: String?) {
            self.startedAt = startedAt
            self.memberCount = memberCount
            self.placeName = placeName
        }
    }

    public var gatheringId: UUID
    public init(gatheringId: UUID) { self.gatheringId = gatheringId }
}

/// Ending every Live Activity there is, from either process.
///
/// THE END BUTTON RELAUNCHES THE APP COLD. It is tapped from a lock screen on
/// a phone that has been face down for an hour, by which point the app has
/// usually been terminated — so the process that services the intent has no
/// memory of the evening, no `AppState` with a session in it, and nothing to
/// tear down. It ended the row in the database and left the activity sitting
/// on the lock screen, counting up for an evening that was over, which from
/// the lock screen is indistinguishable from a button that does nothing.
///
/// So the teardown lives here, where both the intent and the app can reach it,
/// and the intent does it itself rather than hoping the app gets there.
public enum ReclaimActivity {
    public static func endAll() async {
        for activity in Activity<ReclaimActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
