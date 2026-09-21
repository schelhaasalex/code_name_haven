import Foundation
import Supabase

/// The live implementation.
///
/// Every RPC here is a wrapper in `public` (see migration 0005) rather than the
/// function in `app` — PostgREST only serves exposed schemas, and `app` is
/// deliberately not one.
///
/// NOTE FOR THE FIRST BUILD: this file and CeremonyEngine are the two most
/// likely to need small adjustments against the installed supabase-swift
/// version. Everything else is plain SwiftUI and Foundation.
public final class SupabaseRepository: Repository, @unchecked Sendable {

    public let client: SupabaseClient

    public init(url: URL, key: String) {
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    public convenience init(bundle: Bundle = .main) {
        let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
        guard let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL missing. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig.")
        }
        self.init(url: url, key: key)
    }

    private func requireUser() throws -> UUID {
        guard let id = client.auth.currentUser?.id else { throw ReclaimError.notAuthenticated }
        return id
    }

    // MARK: - Own rows

    public func myProfile() async throws -> Profile? {
        let me = try requireUser()
        let rows: [Profile] = try await client
            .from("profiles").select().eq("id", value: me).limit(1)
            .execute().value
        return rows.first
    }

    public func upsertProfile(displayName: String?) async throws -> Profile {
        let me = try requireUser()
        struct Row: Encodable { let id: UUID; let display_name: String? }
        let rows: [Profile] = try await client
            .from("profiles")
            .upsert(Row(id: me, display_name: displayName))
            .select()
            .execute().value
        guard let p = rows.first else { throw ReclaimError.notAuthenticated }
        return p
    }

    public func updateProfile(nudgeEnabled: Bool, nudgeHour: Int) async throws {
        let me = try requireUser()
        struct Row: Encodable { let nudge_enabled: Bool; let nudge_hour: Int }
        try await client.from("profiles")
            .update(Row(nudge_enabled: nudgeEnabled, nudge_hour: nudgeHour))
            .eq("id", value: me)
            .execute()
    }

    /// App Store guideline 5.1.1(v): deletion must be available in-app.
    /// Deleting the profile cascades the user's sessions; places survive and
    /// ownership moves, via the trigger in migration 0001.
    public func deleteAccount() async throws {
        let me = try requireUser()
        try await client.from("profiles").delete().eq("id", value: me).execute()
        try await client.auth.signOut()
    }

    public func myPlaces() async throws -> [Place] {
        try await client.from("places").select()
            .is("merged_into", value: nil)
            .order("created_at", ascending: false)
            .execute().value
    }

    public func place(_ id: UUID) async throws -> Place? {
        let rows: [Place] = try await client.from("places").select()
            .eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    public func rename(place id: UUID, to name: String) async throws {
        struct Row: Encodable { let name: String }
        try await client.from("places").update(Row(name: name))
            .eq("id", value: id).execute()
    }

    public func liveSession() async throws -> Session? {
        let me = try requireUser()
        let rows: [Session] = try await client.from("sessions").select()
            .eq("profile_id", value: me).is("ended_at", value: nil)
            .limit(1).execute().value
        return rows.first
    }

    public func gathering(_ id: UUID) async throws -> Gathering? {
        let rows: [Gathering] = try await client.from("gatherings").select()
            .eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    public func mySessions(since: Date) async throws -> [Session] {
        let me = try requireUser()
        return try await client.from("sessions").select()
            .eq("profile_id", value: me)
            .gte("started_at", value: since.ISO8601Format())
            .order("started_at", ascending: false)
            .execute().value
    }

    public func delete(session id: UUID) async throws {
        try await client.from("sessions").delete().eq("id", value: id).execute()
    }

    // MARK: - RPCs

    public func startOrJoin(place: UUID?, source: SessionSource) async throws -> UUID {
        struct P: Encodable { let p_place: UUID?; let p_source: String; let p_tz: String }
        return try await client
            .rpc("start_or_join", params: P(p_place: place, p_source: source.rawValue,
                                            p_tz: timeZoneIdentifier))
            .execute().value
    }

    @discardableResult
    public func endSession(_ id: UUID?) async throws -> Int? {
        struct P: Encodable { let p_session: UUID? }
        return try await client.rpc("end_session", params: P(p_session: id))
            .execute().value
    }

    public func recordRetroactive(from: Date, to: Date) async throws -> UUID {
        struct P: Encodable { let p_started: String; let p_ended: String; let p_tz: String }
        return try await client.rpc("record_retroactive",
            params: P(p_started: from.ISO8601Format(), p_ended: to.ISO8601Format(),
                      p_tz: timeZoneIdentifier))
            .execute().value
    }

    public func members(of gathering: UUID) async throws -> [Member] {
        struct P: Encodable { let p_gathering: UUID }
        return try await client.rpc("gathering_members", params: P(p_gathering: gathering))
            .execute().value
    }

    public func summary(of place: UUID) async throws -> PlaceSummary {
        struct P: Encodable { let p_place: UUID }
        let rows: [PlaceSummary] = try await client
            .rpc("place_summary", params: P(p_place: place)).execute().value
        guard let s = rows.first else { throw ReclaimError.placeNotFound }
        return s
    }

    public func myRhythm() async throws -> Rhythm {
        let rows: [Rhythm] = try await client.rpc("my_rhythm").execute().value
        return rows.first ?? .empty
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

    public func mergePlaces(from: UUID, into: UUID) async throws {
        struct P: Encodable { let p_from: UUID; let p_into: UUID }
        try await client.rpc("merge_places", params: P(p_from: from, p_into: into)).execute()
    }
}
