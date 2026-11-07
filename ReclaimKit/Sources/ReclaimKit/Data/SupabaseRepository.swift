import Foundation
import Supabase

/// The live implementation.
///
/// Every RPC here is a wrapper in `public` (see migration 0005) rather than the
/// function in `app` — PostgREST only serves exposed schemas, and `app` is
/// deliberately not one.
///
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

    // MARK: - Who you are

    /// Anonymous sign-ins have to be allowed in the project's Auth settings.
    /// The profile row is this app's to make — nothing in the database does —
    /// with no name, because nothing here asks for one.
    public func signInAnonymously() async throws {
        if client.auth.currentUser == nil {
            try await client.auth.signInAnonymously()
        }
        let me = try requireUser()
        struct Row: Encodable { let id: UUID }
        try await client.from("profiles").upsert(Row(id: me), ignoreDuplicates: true).execute()
    }

    // MARK: - Own rows

    public func myProfile() async throws -> Profile? {
        let me = try requireUser()
        let rows: [Profile] = try await client
            .from("profiles").select().eq("id", value: me).limit(1)
            .execute().value
        return rows.first
    }

    /// App Store guideline 5.1.1(v): deletion must be available in-app. The
    /// server does it (0020): the login can't be removed from a phone.
    public func deleteAccount() async throws {
        _ = try requireUser()
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
    }

    public func isKept() async -> Bool {
        guard let user = client.auth.currentUser else { return false }
        return !user.isAnonymous
    }

    /// Needs "Allow manual linking" in the project's Auth settings.
    public func keep(appleIdToken: String, nonce: String) async throws {
        do {
            _ = try await client.auth.linkIdentityWithIdToken(
                credentials: .init(provider: .apple, idToken: appleIdToken, nonce: nonce))
        } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
            throw AccountKeeping.elsewhere
        }
    }

    public func signIn(appleIdToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: appleIdToken, nonce: nonce))
        try await signInAnonymously()   // the profile row, if this login has none
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

    public func myEvenings() async throws -> EveningTotal {
        let rows: [EveningTotal] = try await client.rpc("my_evenings").execute().value
        return rows.first ?? .zero
    }

}
