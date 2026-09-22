import Foundation
import Supabase

/// The three calls behind the radio (migration 0010). A key that dies with
/// the evening it belongs to, in one direction and back.
extension SupabaseRepository {

    /// A key to hand out while this phone is down, or nil when there is
    /// nothing to be found at — no evening running, or one at no place.
    public func openNearby() async throws -> String? {
        try await client.rpc("open_nearby").execute().value
    }

    /// What a key off the air is worth, asked of the server rather than of
    /// the phone that sent it. Nil when the evening is over, when the key is
    /// somebody's idea of a joke, or when you are already at that table.
    ///
    /// Everything the offer does NOT carry is the point: no place and no
    /// name, so screen 4 says "someone nearby" and means it.
    public func nearbyOffer(key: String) async throws -> Invitation? {
        struct P: Encodable { let p_token: String }
        struct Row: Decodable { let gathering: UUID; let people: Int; let since: Date }
        let rows: [Row] = try await client
            .rpc("nearby_offer", params: P(p_token: key)).execute().value
        guard let row = rows.first else { return nil }
        return Invitation(gathering: row.gathering, place: nil, name: nil,
                          count: max(1, row.people), at: row.since, key: key)
    }

    /// Screen 4's one button, for an offer that came over the air. The key
    /// becomes a place on the server and never comes back as one. Returns the
    /// gathering you are now in.
    public func joinNearby(key: String) async throws -> UUID {
        struct P: Encodable { let p_token: String; let p_tz: String }
        return try await client
            .rpc("join_nearby", params: P(p_token: key, p_tz: timeZoneIdentifier))
            .execute().value
    }
}
