import Foundation
import SwiftUI
import Observation
import ReclaimKit

/// One store on the environment. No Composable Architecture, no DI container,
/// no Redux — at 21 screens they are all overhead.
@MainActor
@Observable
public final class AppState {

    public enum Phase: Equatable {
        case loading
        case signedOut
        case ready
    }

    /// The four screens that surface OVER Home rather than being navigated to.
    /// The enum and the order they arrive in live in `ReclaimKit`, so the
    /// precedence can be tested without a phone; the typealias keeps them
    /// spelled `AppState.Interruption` at the call sites.
    public typealias Interruption = ReclaimKit.Interruption

    let repo: any Repository
    let transport: any CeremonyTransport
    /// Joining, announcing and watching, queued off to the side so none of it
    /// holds up the evening (rule 7). Sends mid-evening go to `transport`.
    let link: CeremonyLink

    public var phase: Phase = .loading
    public var profile: Profile?
    public var places: [Place] = []
    public var rhythm: Rhythm = .empty
    /// Distinct qualifying local_dates. A Set because a five-person dinner is
    /// ONE evening — counting sessions would scale every number with household size.
    public var evenings: Set<String> = []
    public var pending: Interruption?
    public var banner: String?
    /// Screen 4. Someone set theirs down at a place you know — the only thing
    /// in the product that interrupts, and only ever to say someone is there.
    public var invitation: Invitation?
    /// Screen 8, held here rather than in the session view: ending clears
    /// `session`, which takes the session view off screen with it.
    public var justEnded: Ended?

    public struct Ended: Equatable {
        public let startedAt: Date
        public let minutes: Int
        public let people: Int
        public let place: String?
    }
    /// Your own recent sessions and the gatherings they belong to, kept so a
    /// screen can ask where your evenings happened without a round trip each.
    public private(set) var recent: [Session] = []
    /// Not private: `AppState+Places` is a different file, and Swift's
    /// `private` stops at the file edge.
    var gatherings: [UUID: Gathering] = [:]

    // the live session
    public var session: Session?
    public var gathering: Gathering?
    public var members: [Member] = []
    public var startedAt: Date?
    public var iAmFaceDown = false

    let faceDown = FaceDownSensor()
    var pump: Task<Void, Never>?
    var invitePump: Task<Void, Never>?
    /// The places being listened at, so a return to the foreground doesn't
    /// resubscribe every one of them.
    var watching: [UUID] = []

    public init(repo: any Repository, transport: any CeremonyTransport = LocalCeremonyTransport()) {
        self.repo = repo
        self.transport = transport
        self.link = CeremonyLink(transport: transport)
    }

    public var isLive: Bool { session?.isLive == true }

    public var placeName: String? {
        guard let id = gathering?.placeId else { return nil }
        return places.first { $0.id == id }?.name
    }

    /// The suggestion on Home. A guess from history, NOT from location —
    /// nothing in this app reads where you are. Nil when your recent evenings
    /// weren't at any place, and then Home suggests nothing.
    public var usualPlace: Place? {
        UsualPlace.among(recent, gatherings: gatherings, places: places)
    }

    // MARK: - Lifecycle

    /// Runs at launch and on every return to the foreground. A failed read
    /// keeps what was already known — offline is not signed out, and not
    /// "nothing is running".
    public func load() async {
        let p: Profile?
        do {
            p = try await repo.myProfile()
        } catch ReclaimError.notAuthenticated {
            phase = .signedOut; return
        } catch {
            if phase == .loading { phase = .signedOut }
            return
        }
        guard let p else { phase = .signedOut; return }
        profile = p
        phase = .ready
        async let places = repo.myPlaces()
        async let rhythm = repo.myRhythm()
        async let live = repo.liveSession()
        self.places = (try? await places) ?? self.places
        self.rhythm = (try? await rhythm) ?? self.rhythm
        await loadEvenings()
        let found: Result<Session?, any Error>
        do { found = .success(try await live) } catch { found = .failure(error) }
        await reconcile(Reconciliation.between(running: session, database: found))
    }

    /// The qualifying days behind the dot week on Home and the grid on screen 10.
    /// Distinct local_dates, because a five-person dinner is one evening.
    ///
    /// Also pulls the gatherings those sessions belong to, in one query, which
    /// is what lets a screen ask where YOUR evenings happened. The place's own
    /// totals never come from here — those are `place_summary`, an aggregate
    /// over everyone, because the client may not read another person's rows.
    func loadEvenings() async {
        let since = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
        recent = (try? await repo.mySessions(since: since)) ?? recent
        evenings = Set(recent.filter(\.qualifying).map(\.localDate))

        let ids = Array(Set(recent.map(\.gatheringId)))
        guard let found = try? await repo.gatherings(ids: ids) else { return }
        gatherings = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - Interruptions
    // At most one per launch, in this order. None of them is a notification:
    // they wait on Home until the person next looks.

    public func computeInterruption() async {
        guard pending == nil, phase == .ready else { return }
        let lately = (try? await repo.mySessions(since: .now.addingTimeInterval(-60 * 60 * 36))) ?? []
        pending = await Interruption.first(
            recent: lately,
            rhythm: rhythm,
            // Distinct dates over the last five weeks, not sessions in the last
            // day and a half: screen 20 arrives after five EVENINGS.
            evenings: evenings.count,
            oneTapOffered: OneTapOffer.hasBeenOffered,
            stationary: { await RetroactiveCredit.candidate(excluding: lately) })
    }

    public func dismissInterruption() { pending = nil }

    /// Signing out has to reach the screen, not just the server: `load()` then
    /// finds nobody and shows Welcome. It used to call the auth client directly
    /// and leave the app looking signed in.
    public func signOut() async {
        do {
            try await repo.signOut()
            profile = nil
            await load()
        } catch {
            banner = t("error.retry")
        }
    }

    public func dismissInvitation() { invitation = nil }

}
