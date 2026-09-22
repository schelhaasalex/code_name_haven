import Foundation

/// Everything the app can ask for.
///
/// THE RULE: the client never reads another person's rows. `sessions` and
/// `profiles` are own-rows-only at the database, so anything crossing a person
/// boundary appears here as an RPC returning an aggregate — never a table read.
/// If a screen needs someone else's data and there's no call for it here, the
/// answer is a new RPC, not a wider policy.
public protocol Repository: Sendable {

    // ---- your own rows, read directly ----
    func myProfile() async throws -> Profile?
    func upsertProfile(displayName: String?) async throws -> Profile
    func updateProfile(nudgeEnabled: Bool, nudgeHour: Int) async throws
    func deleteAccount() async throws
    func signOut() async throws

    func myPlaces() async throws -> [Place]
    func place(_ id: UUID) async throws -> Place?
    func rename(place id: UUID, to name: String) async throws

    func liveSession() async throws -> Session?
    func gathering(_ id: UUID) async throws -> Gathering?
    /// The gatherings behind your own sessions, in one query.
    ///
    /// A gathering is a shared object rather than a person's row — you may read
    /// the ones you were in — so this stays inside the rule: it says WHERE your
    /// own evenings happened, and nothing about whose they were.
    func gatherings(ids: [UUID]) async throws -> [Gathering]
    func mySessions(since: Date) async throws -> [Session]
    func delete(session id: UUID) async throws

    // ---- anything involving anyone else: RPC only ----
    func startOrJoin(place: UUID?, source: SessionSource) async throws -> UUID
    @discardableResult func endSession(_ id: UUID?) async throws -> Int?
    /// Scanning a card, or picking a place, after the phone is already down.
    /// Joins the evening open there, or makes yours the place's. Returns the
    /// gathering you are now in. Migration 0007.
    func moveEvening(to place: UUID) async throws -> UUID
    func recordRetroactive(from: Date, to: Date) async throws -> UUID
    func members(of gathering: UUID) async throws -> [Member]
    func summary(of place: UUID) async throws -> PlaceSummary
    func myRhythm() async throws -> Rhythm
    func resolvePlace(secret: String) async throws -> UUID?
    func createPlace(handle: String, secret: String, name: String?) async throws -> UUID
    func nameSomewhere(handle: String, secret: String, name: String) async throws -> UUID
    func mergePlaces(from: UUID, into: UUID) async throws
    /// A week-long link into one of your places (migration 0008). Joins the
    /// place; starts nothing.
    func createInvite(place: UUID) async throws -> String
    func acceptInvite(token: String) async throws -> InviteAcceptance
    /// Whether anyone else shares one of your places. One boolean — never
    /// who, never how many (migration 0009).
    func hasCompany() async throws -> Bool

    // ---- the radio (migration 0010) ----
    /// A key for the phone that is down to hand to the phones around it. Nil
    /// when there is nothing to find: no evening, or one at no place.
    func openNearby() async throws -> String?
    /// What a key picked up off the air is worth. Nil when that evening is
    /// over, or when you are already in it.
    func nearbyOffer(key: String) async throws -> Invitation?
    /// Join the evening that key belongs to. The key becomes a place on the
    /// server and never leaves it as one. Returns the gathering.
    func joinNearby(key: String) async throws -> UUID
}

public extension Repository {
    /// The timezone identifier the database uses to compute `local_date`.
    /// Sessions credit to the day they started, in the user's own zone.
    var timeZoneIdentifier: String { TimeZone.current.identifier }
}

public enum ReclaimError: LocalizedError {
    case notAuthenticated
    case noLiveSession
    case placeNotFound

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: "You're signed out."
        case .noLiveSession:    "Nothing is running right now."
        case .placeNotFound:    "That card doesn't match a place."
        }
    }
}
