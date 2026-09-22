import Foundation

/// "Someone just set theirs down at a place you know."
///
/// Sent by the person who started it, carrying their own display name — they
/// know it, it is their row, and telling the table who you are is the point.
/// Nobody's name reaches anyone any other way: the RPC that returns members
/// checks that you are IN the gathering first.
///
/// The SAME offer arrives the other way too: off the radio, from a phone at a
/// table you have never been to (`Nearby`, migration 0010). That one carries
/// no place and no name, because until you tap, the app has been told nothing
/// but that an evening near you is open and how many phones are down in it —
/// which is exactly what screen 4 then says.
public struct Invitation: Sendable, Equatable, Identifiable, Codable {
    public let gathering: UUID
    /// Where, when it came over the channel. Nil when it came over the air:
    /// the key below is the only way in, and it resolves on the server.
    public let place: UUID?
    public let name: String?
    /// How many are down, according to the person who sent it. The receiver
    /// cannot look this up — `gathering_members` checks membership first, and
    /// they aren't a member yet — so it is told rather than fetched, and it
    /// only ever counts people who HAVE set theirs down.
    public let count: Int
    public let at: Date
    /// The radio's short-lived key, worthless once that evening ends. Never
    /// broadcast: it is read off one phone by one other phone, and never
    /// leaves this one except back to the server that minted it.
    public let key: String?

    public var id: UUID { gathering }

    public init(gathering: UUID, place: UUID?, name: String?, count: Int, at: Date,
                key: String? = nil) {
        self.gathering = gathering; self.place = place; self.name = name
        self.count = count; self.at = at; self.key = key
    }

    /// True for the offer that came off a phone across the table rather than
    /// through a place you both know.
    public var isNearby: Bool { key != nil }
}
