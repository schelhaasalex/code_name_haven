import Foundation
import Supabase

/// Places, split from `SupabaseRepository` so neither file is a long one:
/// reading them (by named columns — never every column, see
/// `Place.readableColumns`), making and naming them, merging, moving an
/// evening to one, and the invites that bring people into them.
extension SupabaseRepository {

    public func myPlaces() async throws -> [Place] {
        try await client.from("places").select(Place.readableColumns)
            .is("merged_into", value: nil)
            .order("created_at", ascending: false)
            .execute().value
    }

    public func place(_ id: UUID) async throws -> Place? {
        let rows: [Place] = try await client.from("places").select(Place.readableColumns)
            .eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    public func rename(place id: UUID, to name: String) async throws {
        struct Row: Encodable { let name: String }
        try await client.from("places").update(Row(name: name))
            .eq("id", value: id).execute()
    }

    public func moveEvening(to place: UUID) async throws -> UUID {
        struct P: Encodable { let p_place: UUID }
        return try await client.rpc("move_evening", params: P(p_place: place)).execute().value
    }

    public func resolvePlace(secret: String) async throws -> UUID? {
        struct P: Encodable { let p_secret: String }
        return try await client.rpc("resolve_place", params: P(p_secret: secret))
            .execute().value
    }

    public func createPlace(handle: String, secret: String, name: String?) async throws -> UUID {
        struct P: Encodable { let p_handle: String; let p_secret: String; let p_name: String? }
        return try await client.rpc("create_place",
            params: P(p_handle: handle, p_secret: secret, p_name: name))
            .execute().value
    }

    public func nameSomewhere(handle: String, secret: String, name: String) async throws -> UUID {
        struct P: Encodable { let p_handle: String; let p_secret: String; let p_name: String }
        return try await client.rpc("name_somewhere",
            params: P(p_handle: handle, p_secret: secret, p_name: name))
            .execute().value
    }

    public func createInvite(place: UUID) async throws -> String {
        struct P: Encodable { let p_place: UUID }
        return try await client.rpc("create_invite", params: P(p_place: place)).execute().value
    }

    public func acceptInvite(token: String) async throws -> InviteAcceptance {
        struct P: Encodable { let p_token: String }
        let rows: [InviteAcceptance] = try await client
            .rpc("accept_invite", params: P(p_token: token)).execute().value
        guard let row = rows.first else { throw ReclaimError.placeNotFound }
        return row
    }

    public func mergePlaces(from: UUID, into: UUID) async throws {
        struct P: Encodable { let p_from: UUID; let p_into: UUID }
        try await client.rpc("merge_places", params: P(p_from: from, p_into: into)).execute()
    }

    /// Whether anyone else shares one of your places — one boolean, never who
    /// (migration 0009). Home's invite line stays until this is true.
    public func hasCompany() async throws -> Bool {
        try await client.rpc("has_company").execute().value
    }
}
