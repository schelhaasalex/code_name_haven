import Foundation

/// A Live Activity the server starts, for an evening the phone started in the
/// background (`start-live-activity`, migration 0015).
///
/// The phone encodes the activity itself, with a plain `JSONEncoder` — the
/// same defaults ActivityKit decodes a push with. A date, in particular, is
/// seconds since 2001, not an ISO string; written any other way, the push
/// arrives and the Live Activity silently never appears. So nothing on the
/// server touches these values: it passes on what the phone wrote.
public enum RemoteActivity {

    /// The body for `start-live-activity`.
    public static func startBody(gatheringId: UUID,
                                 state: ReclaimActivityAttributes.ContentState,
                                 title: String, body: String) throws -> Data {
        let encoder = JSONEncoder()
        func object<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: encoder.encode(value))
        }
        let request: [String: Any] = [
            "gatheringId": gatheringId.uuidString,
            "attributes": try object(ReclaimActivityAttributes(gatheringId: gatheringId)),
            "contentState": try object(state),
            "alert": ["title": title, "body": body]
        ]
        return try JSONSerialization.data(withJSONObject: request)
    }

    /// The token iOS hands out, as Apple's push service wants it.
    public static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}
