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
        /// How many of the ring's four segments are full (`EveningCharge`).
        /// Sent by the server as the evening goes on; the phone is asleep.
        public var stage: Int

        public init(startedAt: Date, memberCount: Int, placeName: String?, stage: Int = 0) {
            self.startedAt = startedAt
            self.memberCount = memberCount
            self.placeName = placeName
            self.stage = stage
        }

        /// A state written before the ring charged has no stage; it decodes
        /// as the first, rather than not at all — which on a lock screen
        /// looks like the Live Activity simply never arriving.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            startedAt = try c.decode(Date.self, forKey: .startedAt)
            memberCount = try c.decode(Int.self, forKey: .memberCount)
            placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
            stage = try c.decodeIfPresent(Int.self, forKey: .stage) ?? 0
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
