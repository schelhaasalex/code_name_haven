import Foundation
import SwiftUI
import Observation
import ReclaimKit

/// One store on the environment. No Composable Architecture, no DI container,
/// no Redux — at a handful of screens they are all overhead.
///
/// The app is the box's: putting a phone in it starts the evening, taking it
/// out ends it (`AppState+Box`), and everything here is what that leaves to
/// show — the evening while it runs, and what the box has become.
@MainActor
@Observable
public final class AppState {

    public enum Phase: Equatable {
        case loading
        /// No account, and none could be made: the first launch needs the
        /// network once. Retried on every return to the foreground.
        case unreachable
        case ready
    }

    let repo: any Repository

    public var phase: Phase = .loading
    public var profile: Profile?
    public var places: [Place] = []
    /// This phone's box, the moment its tag or code was read — whether or not
    /// Bluetooth found its radio. Nil until then, and Home asks for one.
    public var boxPlace: UUID?
    /// What the box has become: every evening anyone has had at it. Nil until
    /// the database has said, and nothing claims a number before then.
    public var boxSummary: PlaceSummary?
    /// Distinct qualifying local_dates of your own, for this week's dots. A
    /// Set because a five-person dinner is ONE evening.
    public var evenings: Set<String> = []
    /// All of them (migration 0011). Nil until the database has answered:
    /// "we haven't been told" and "you have had none" are different things.
    public var eveningTotal: EveningTotal?
    /// Screen 13: an evening the server had to close, said once.
    public var closedForYou: Session?
    public var banner: String?
    /// Screen 8, held here rather than in the session view: ending clears
    /// `session`, which takes the session view off screen with it.
    public var justEnded: Ended?

    public struct Ended: Equatable {
        public let startedAt: Date
        public let endedAt: Date
        public let minutes: Int
        public let people: Int
        public let place: String?
        public let placeId: UUID?
        /// Your evenings as they were, and whether this one adds to them — so
        /// screen 8 can show tonight's dot fill in without waiting on a reload.
        public let landing: EveningLanding
    }

    // the live evening
    public var session: Session?
    public var gathering: Gathering?
    public var members: [Member] = []
    public var startedAt: Date?

    /// The box, if this phone has one: a standing connection that wakes the
    /// app when a slot fills or empties (`AppState+Box`).
    let boxLink = BoxLink()
    /// Explained already, so a dismissed screen 13 doesn't come back on the
    /// next launch. This phone's own note; nothing is sent.
    private static let explainedKey = "reclaim.autoclosed.explained"

    /// `boxPlace` is for previews and the sample household, which have a box
    /// nobody read.
    public init(repo: any Repository, boxPlace: UUID? = BoxPairing.current?.place) {
        self.repo = repo
        self.boxPlace = boxPlace
    }

    public var isLive: Bool { session?.isLive == true }

    public var box: Place? { places.first { $0.id == boxPlace } }

    public var placeName: String? {
        guard let id = gathering?.placeId else { return nil }
        return places.first { $0.id == id }?.name
    }

    // MARK: - Lifecycle

    /// Runs at launch and on every return to the foreground. A failed read
    /// keeps what was already known — offline is not "nothing is running".
    public func load() async {
        guard let p = await account() else {
            if phase != .ready { phase = .unreachable }
            return
        }
        profile = p
        phase = .ready
        async let places = repo.myPlaces()
        async let live = repo.liveSession()
        self.places = (try? await places) ?? self.places
        await loadEvenings()
        let found: Result<Session?, any Error>
        do { found = .success(try await live) } catch { found = .failure(error) }
        await reconcile(Reconciliation.between(running: session, database: found))
        await checkDock()
    }

    /// Yours, or a new one made silently. There is no sign-in screen.
    private func account() async -> Profile? {
        if let p = try? await repo.myProfile() { return p }
        do {
            try await repo.signInAnonymously()
            return try await repo.myProfile()
        } catch {
            return nil
        }
    }

    /// Your own evenings, for the dots and the count — and the box's, which
    /// are everyone's and come only as `place_summary`'s aggregate.
    func loadEvenings() async {
        let since = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
        let recent = (try? await repo.mySessions(since: since)) ?? []
        evenings = Set(recent.filter(\.qualifying).map(\.localDate))
        eveningTotal = (try? await repo.myEvenings()) ?? eveningTotal
        if let boxPlace { boxSummary = (try? await repo.summary(of: boxPlace)) ?? boxSummary }

        let lately = recent.filter { $0.startedAt > .now.addingTimeInterval(-AutoClosed.window) }
        if closedForYou == nil, let closed = AutoClosed.latest(in: lately),
           UserDefaults.standard.string(forKey: Self.explainedKey) != closed.id.uuidString {
            closedForYou = closed
        }
    }

    public func dismissClosedForYou() {
        if let closed = closedForYou {
            UserDefaults.standard.set(closed.id.uuidString, forKey: Self.explainedKey)
        }
        closedForYou = nil
    }

    // MARK: - The box and the account

    /// Only whoever's phone first read the box can name it (`places_update_owner`).
    public var canRenameBox: Bool { box?.createdBy != nil && box?.createdBy == profile?.id }

    public func renameBox(to name: String) async {
        guard let id = boxPlace else { return }
        do {
            try await repo.rename(place: id, to: name)
            places = (try? await repo.myPlaces()) ?? places
        } catch {
            banner = t("error.retry")
        }
    }

    /// This phone stops being the box's. The box, and everything it kept,
    /// stays; reading its tag or code again brings this phone back.
    public func forgetBox() {
        BoxPairing.current = nil
        boxPlace = nil
        boxSummary = nil
    }

    /// App Store guideline 5.1.1(v). Your evenings go; a new, empty account
    /// takes this one's place on the next load.
    public func deleteAccount() async {
        try? await repo.deleteAccount()
        session = nil; gathering = nil; members = []; startedAt = nil
        evenings = []; eveningTotal = nil
        await load()
    }
}
