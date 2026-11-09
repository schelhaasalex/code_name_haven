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
    /// Whose sky the evening mark draws.
    public var skySeed: UInt64 { EveningMarkLayout.seed(profile?.id) }
    public var places: [Place] = []
    /// This phone's boxes, in the order they were met — each from the moment
    /// its card or a tag was read, whether or not Bluetooth found its radio.
    /// Empty until then, and Home asks for one.
    public var boxPlaces: [UUID]
    /// The box this phone was last at, which Home leads with. This phone's
    /// own note.
    public var lastBox: UUID? = UserDefaults.standard.string(forKey: AppState.lastBoxKey).flatMap(UUID.init) {
        didSet { UserDefaults.standard.set(lastBox?.uuidString, forKey: AppState.lastBoxKey) }
    }
    static let lastBoxKey = "reclaim.box.last"
    /// Listening for the box's radio after its code or a tag was read, and
    /// what came of it. Only the scanner shows it; nil until a first read.
    public var pairing: Pairing?
    /// `bluetoothOff` is its own answer: "bring it closer" is the wrong advice
    /// to a phone that can't hear anything at all.
    public enum Pairing: Equatable { case listening, paired, notHeard, bluetoothOff }
    /// What each box has become: every evening anyone has had at it. Missing
    /// until the database has said, and nothing claims a number before then.
    public var boxSummaries: [UUID: PlaceSummary] = [:]
    /// Distinct qualifying local_dates of your own, for this week's dots. A
    /// Set because a five-person dinner is ONE evening.
    public var evenings: Set<String> = []
    /// All of them (migration 0011). Nil until the database has answered:
    /// "we haven't been told" and "you have had none" are different things.
    public var eveningTotal: EveningTotal?
    /// Screen 13: an evening the server had to close, said once.
    public var closedForYou: Session?
    /// Something that didn't go through, said quietly over whatever is
    /// showing (`Banner`, from `RootView`) and gone after a moment.
    public var banner: String?
    /// Tied to an Apple ID, so the evenings outlive this phone. Nil until
    /// asked (`AppState+Account`).
    public var kept: Bool?
    /// An Apple ID that already keeps another account: offered, not taken.
    public var keptElsewhere: AppleToken?
    public struct AppleToken: Equatable { let idToken: String; let nonce: String }
    /// Ticks whenever a box's radio connects, goes or Bluetooth changes, so
    /// what Settings says about it is read again.
    public var radioTick = 0
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
    /// Out of the box and counting down to the evening's end (`leaving`).
    public var leavingUntil: Date?
    public var startedAt: Date?

    /// The box, if this phone has one: a standing connection that wakes the
    /// app when a slot fills or empties (`AppState+Box`).
    let boxLink = BoxLink()
    /// Explained already, so a dismissed screen 13 doesn't come back on the
    /// next launch. This phone's own note; nothing is sent.
    private static let explainedKey = "reclaim.autoclosed.explained"

    /// `boxPlaces` is for previews and the sample household, which have boxes
    /// nobody read.
    public init(repo: any Repository, boxPlaces: [UUID] = BoxPairing.all.map(\.place)) {
        self.repo = repo
        self.boxPlaces = boxPlaces
    }

    public var isLive: Bool { session?.isLive == true }

    /// The box Home leads with: the one this phone was last at, or else the
    /// one it met most recently.
    public var boxPlace: UUID? {
        if let lastBox, boxPlaces.contains(lastBox) { return lastBox }
        return boxPlaces.last
    }
    public var otherBoxes: [UUID] { boxPlaces.filter { $0 != boxPlace } }
    public var box: Place? { boxPlace.flatMap(place) }
    public var boxSummary: PlaceSummary? { boxPlace.flatMap { boxSummaries[$0] } }

    public func place(_ id: UUID) -> Place? { places.first { $0.id == id } }

    /// The evening's box, by name — its own, or the one it goes by until
    /// someone names it.
    public var placeName: String? { gathering?.placeId.map(name(of:)) }

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
        // A box met before boxes had names, or whose naming didn't reach the
        // server, is named now rather than only at its next scan.
        for id in boxPlaces { await nameIfUnnamed(id) }
        await loadEvenings()
        let found: Result<Session?, any Error>
        do { found = .success(try await live) } catch { found = .failure(error) }
        await reconcile(Reconciliation.between(running: session, database: found))
        kept = await repo.isKept()
        noteHowThingsAre()
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
        for id in boxPlaces {
            boxSummaries[id] = (try? await repo.summary(of: id)) ?? boxSummaries[id]
        }

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
}
