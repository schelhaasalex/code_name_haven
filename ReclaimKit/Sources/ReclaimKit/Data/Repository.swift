import Foundation

/// Everything the app can ask for.
///
/// THE RULE: the client never reads another person's rows. `sessions` and
/// `profiles` are own-rows-only at the database, so anything crossing a person
/// boundary appears here as an RPC returning an aggregate — never a table read.
/// If a screen needs someone else's data and there's no call for it here, the
/// answer is a new RPC, not a wider policy.
public protocol Repository: Sendable {

    // ---- who you are ----
    /// An account made silently on first launch — no sign-in screen. Does
    /// nothing if there is one already.
    func signInAnonymously() async throws
    func myProfile() async throws -> Profile?
    /// The login, its profile and its boxes go; its evenings stay in the
    /// boxes' totals, owned by nobody (migration 0020).
    func deleteAccount() async throws
    /// Kept beyond this phone — tied to an Apple ID — rather than the silent
    /// account that goes with the app.
    func isKept() async -> Bool
    /// Ties this account to an Apple ID, so its evenings survive a new phone
    /// or a reinstall. Throws `AccountKeeping.elsewhere` when that Apple ID
    /// already keeps another account.
    func keep(appleIdToken: String, nonce: String) async throws
    /// That other account, instead of this one: this phone signs in to it.
    func signIn(appleIdToken: String, nonce: String) async throws

    // ---- your own rows, read directly ----
    func myPlaces() async throws -> [Place]
    func rename(place id: UUID, to name: String) async throws

    func liveSession() async throws -> Session?
    func gathering(_ id: UUID) async throws -> Gathering?
    func mySessions(since: Date) async throws -> [Session]
    func delete(session id: UUID) async throws

    // ---- anything involving anyone else: RPC only ----
    func startOrJoin(place: UUID?, source: SessionSource) async throws -> UUID
    @discardableResult func endSession(_ id: UUID?) async throws -> Int?
    func members(of gathering: UUID) async throws -> [Member]
    /// The box's whole life: every evening anyone has had at it, and how long
    /// it was gathered. An aggregate — never whose.
    func summary(of place: UUID) async throws -> PlaceSummary
    /// Every evening you've had, and the first (migration 0011). Your own
    /// rows only, counted as days.
    func myEvenings() async throws -> EveningTotal
    /// A box's place, found or made by whoever reads its tag or code first
    /// (migrations 0013, 0017), and you one of its people. Nil means the
    /// handle was taken: draw another and ask again.
    func dockPlace(secret: String, handle: String) async throws -> UUID?

    // ---- the lock screen (migrations 0015, 0016) ----
    /// This device's push-to-start token, filed as yours.
    func saveActivityToken(_ token: String, environment: String) async throws
    /// Asks the server to show this evening's Live Activity, which the phone
    /// couldn't do itself in the background. `body` is `RemoteActivity.startBody`.
    func startActivityRemotely(body: Data) async throws
    /// A running Live Activity's own token, so the server can push the ring's
    /// steps to it. `state` is `RemoteActivity.stateJSON`.
    func saveLiveActivity(token: String, gatheringId: UUID, environment: String, state: String) async throws

    // ---- what goes wrong (migration 0021) ----
    /// One of a fixed list of moments, against a box this person belongs to.
    /// Write-only: nobody's client can read notes back.
    func note(_ note: Note, place: UUID?, detail: [String: String]) async throws
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
        case .placeNotFound:    "That box isn't one we know."
        }
    }
}

/// Why keeping an account with an Apple ID didn't happen.
public enum AccountKeeping: Error, Equatable {
    /// The Apple ID already keeps another account — this person's, from
    /// another phone or an earlier install.
    case elsewhere
}
