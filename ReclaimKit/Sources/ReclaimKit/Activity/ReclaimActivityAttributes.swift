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
