import Foundation

/// What accepting an invite tells you: the place you're now one of the people
/// of, and who asked you. `accept_invite` returns it only once you're in.
public struct InviteAcceptance: Codable, Hashable, Sendable, Identifiable {
    public let placeId: UUID
    /// Nil for a place nobody has named.
    public let placeName: String?
    /// Nil if the inviter has no name on their profile.
    public let invitedBy: String?

    public var id: UUID { placeId }

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case placeName = "place_name"
        case invitedBy = "invited_by"
    }

    public init(placeId: UUID, placeName: String?, invitedBy: String?) {
        self.placeId = placeId; self.placeName = placeName; self.invitedBy = invitedBy
    }
}
