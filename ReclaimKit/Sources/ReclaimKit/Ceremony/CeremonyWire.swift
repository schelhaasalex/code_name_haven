import Foundation
import Supabase

/// What goes over a Realtime broadcast, and how it comes back.
///
/// Separated from the channel handling so the round trip can be tested
/// against supabase-swift's own encoder, with no socket. Both halves of the
/// round trip had a bug before this existed, and neither threw — every event
/// was dropped at a `continue`:
///
/// - `broadcastStream(event:)` yields the whole broadcast envelope,
///   `{event, payload, type}`, not the payload. What we sent is one level down.
/// - `broadcast(event:message:)` encodes with `JSONEncoder.supabase()`, which
///   writes a `Date` as an ISO-8601 string. A plain `JSONDecoder` expects a
///   number, so decoding has to go through `AnyJSON.decoder`, its pair.
public enum CeremonyWire {

    public struct Payload: Codable, Equatable, Sendable {
        public var kind: String          // "docked" | "facedown" | "released"
        public var sender: String
        public var at: Double?
        public var down: Bool?
    }

    /// Your own event, as the table will receive it.
    public static func payload(for event: CeremonyEvent, from me: UUID) -> Payload {
        switch event {
        case .docked(let at):
            Payload(kind: "docked", sender: me.uuidString, at: at.timeIntervalSince1970, down: nil)
        case .faceDown(_, let down):
            Payload(kind: "facedown", sender: me.uuidString, at: nil, down: down)
        case .released:
            Payload(kind: "released", sender: me.uuidString, at: nil, down: nil)
        }
    }

    /// Someone else's event. Nil for your own, and for anything unrecognised —
    /// a newer build's event kind is not this build's business.
    public static func event(from p: Payload, me: UUID?) -> CeremonyEvent? {
        guard let sender = UUID(uuidString: p.sender), sender != me else { return nil }
        switch p.kind {
        case "docked":
            return .docked(at: p.at.map { Date(timeIntervalSince1970: $0) } ?? .now)
        case "facedown":
            return .faceDown(profile: sender, down: p.down ?? false)
        case "released":
            return .released(profile: sender)
        default:
            return nil
        }
    }

    /// What we sent, taken back out of the envelope it arrives in.
    public static func unwrap<T: Decodable>(_ envelope: JSONObject, as type: T.Type = T.self) -> T? {
        guard let payload = envelope["payload"]?.objectValue else { return nil }
        return try? payload.decode(as: T.self)
    }
}
