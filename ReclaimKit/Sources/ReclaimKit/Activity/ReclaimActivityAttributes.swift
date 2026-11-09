import Foundation
import ActivityKit

/// The Live Activity — screen 7, on the lock screen, the Dynamic Island and
/// the wrist. Nothing on it to press: the box is the only switch. A push can
/// start one from iOS 17.2, and the Watch shows it from iOS 18.
public struct ReclaimActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startedAt: Date
        public var memberCount: Int
        /// Nil when the app can't name the box: the face then says only
        /// since when, never a name for a box that doesn't exist.
        public var placeName: String?
        /// How many of the ring's four segments are full (`EveningCharge`).
        /// Sent by the server as the evening goes on; the phone is asleep.
        public var stage: Int
        /// Out of the box and counting down: the evening ends then, unless
        /// the phone is back. Set by the phone only; the server never sends it.
        public var endingAt: Date?

        public init(startedAt: Date, memberCount: Int, placeName: String?, stage: Int = 0, endingAt: Date? = nil) {
            self.startedAt = startedAt
            self.memberCount = memberCount
            self.placeName = placeName
            self.stage = stage
            self.endingAt = endingAt
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
            endingAt = try c.decodeIfPresent(Date.self, forKey: .endingAt)
        }
    }

    public var gatheringId: UUID
    public init(gatheringId: UUID) { self.gatheringId = gatheringId }
}

/// Ending every Live Activity there is — not only the one this launch
/// started. The box often starts an evening by push while the app is asleep,
/// so the launch that ends it may never have known the activity existed.
public enum ReclaimActivity {
    public static func endAll() async {
        for activity in Activity<ReclaimActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
