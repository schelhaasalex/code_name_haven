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

    public init(repo: any Repository, transport: any CeremonyTransport = LocalCeremonyTransport()) {
        self.repo = repo
        self.transport = transport
    }

    public var isLive: Bool { session?.isLive == true }

    public var placeName: String? {
        guard let id = gathering?.placeId else { return nil }
        return places.first { $0.id == id }?.name
    }

    /// The suggestion on Home. A guess from history, NOT from location —
    /// nothing in this app reads where you are.
    public var usualPlace: Place? { places.first }

    // MARK: - Lifecycle

    public func load() async {
        do {
            guard let p = try await repo.myProfile() else { phase = .signedOut; return }
            profile = p
            phase = .ready
            async let places = repo.myPlaces()
            async let rhythm = repo.myRhythm()
            async let live = repo.liveSession()
            self.places = (try? await places) ?? []
            self.rhythm = (try? await rhythm) ?? .empty
            await loadEvenings()
            if let s = try? await live { await adopt(session: s) }
            else { await watchPlaces() }
        } catch {
            phase = .signedOut
        }
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
        recent = (try? await repo.mySessions(since: since)) ?? []
        evenings = Set(recent.filter(\.qualifying).map(\.localDate))

        let ids = Array(Set(recent.map(\.gatheringId)))
        let found = (try? await repo.gatherings(ids: ids)) ?? []
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

    public func dismissInvitation() { invitation = nil }

}
