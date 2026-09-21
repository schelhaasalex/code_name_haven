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

    // the live session
    public var session: Session?
    public var gathering: Gathering?
    public var members: [Member] = []
    public var startedAt: Date?
    public var iAmFaceDown = false

    private let faceDown = FaceDownSensor()
    private var pump: Task<Void, Never>?

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
            if let s = try? await live, let s { await adopt(session: s) }
        } catch {
            phase = .signedOut
        }
    }

    /// The qualifying days behind the dot week on Home and the grid on screen 10.
    /// Distinct local_dates, because a five-person dinner is one evening.
    private func loadEvenings() async {
        let since = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
        let sessions = (try? await repo.mySessions(since: since)) ?? []
        evenings = Set(sessions.filter(\.qualifying).map(\.localDate))
    }

    // MARK: - The loop

    /// Every way a session begins funnels here: the app, a tag, a control,
    /// Siri, a Shortcut.
    public func setItDown(place: UUID? = nil, source: SessionSource = .app) async {
        let at = Date()
        do {
            let id = try await repo.startOrJoin(place: place, source: source)
            guard let s = try await repo.liveSession(), s.id == id else { return }
            await adopt(session: s, at: at)
            // Render on send, ignore your own echo — otherwise the person who
            // tapped is the last at the table to feel anything.
            Sensation.docked()
            if let me = profile?.id {
                await transport.send(.docked(at: at), from: me)
            }
        } catch {
            banner = "That didn't take. Try again?"
        }
    }

    public func end() async {
        guard let s = session else { return }
        if let me = profile?.id { await transport.send(.released(profile: me), from: me) }
        _ = try? await repo.endSession(s.id)
        Sensation.ended()
        await teardown()
        self.rhythm = (try? await repo.myRhythm()) ?? rhythm
        await loadEvenings()
        await Notifications.reschedule(for: profile)
    }

    private func adopt(session s: Session, at: Date? = nil) async {
        session = s
        startedAt = at ?? s.startedAt
        gathering = try? await repo.gathering(s.gatheringId)
        members = (try? await repo.members(of: s.gatheringId)) ?? []
        try? await transport.join(gathering: s.gatheringId)
        listen()
        faceDown.start { [weak self] down in
            guard let self else { return }
            Task { @MainActor in await self.setFaceDown(down) }
        }
        // Never buzz during a session. A nudge mid-evening is the app becoming
        // the thing it replaces.
        Notifications.silenceForSession()
        await LiveActivityController.start(
            gatheringId: s.gatheringId,
            startedAt: startedAt ?? s.startedAt,
            memberCount: max(1, members.count),
            placeName: placeName)
    }

    private func teardown() async {
        pump?.cancel(); pump = nil
        faceDown.stop()
        await transport.leave()
        await LiveActivityController.end()
        session = nil; gathering = nil; members = []; startedAt = nil
        iAmFaceDown = false
    }

    private func setFaceDown(_ down: Bool) async {
        iAmFaceDown = down
        guard let me = profile?.id else { return }
        await transport.send(.faceDown(profile: me, down: down), from: me)
    }

    private func listen() {
        pump?.cancel()
        let stream = transport.events()
        pump = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: CeremonyEvent) async {
        switch event {
        case .docked:
            // Someone else joined. The count only goes up.
            Sensation.joined()
            await refreshMembers()
        case .faceDown:
            await refreshMembers()
        case .released:
            await refreshMembers()
        }
    }

    public func refreshMembers() async {
        guard let id = session?.gatheringId else { return }
        members = (try? await repo.members(of: id)) ?? members
        await LiveActivityController.update(
            startedAt: startedAt ?? .now,
            memberCount: max(1, members.count),
            placeName: placeName)
    }

    // MARK: - Interruptions
    // At most one per launch, in this order. None of them is a notification:
    // they wait on Home until the person next looks.

    public func computeInterruption() async {
        guard pending == nil, phase == .ready else { return }
        let recent = (try? await repo.mySessions(since: .now.addingTimeInterval(-60 * 60 * 36))) ?? []
        pending = await Interruption.first(
            recent: recent,
            rhythm: rhythm,
            // Distinct dates over the last five weeks, not sessions in the last
            // day and a half: screen 20 arrives after five EVENINGS.
            evenings: evenings.count,
            oneTapOffered: OneTapOffer.hasBeenOffered,
            stationary: { await RetroactiveCredit.candidate(excluding: recent) })
    }

    public func dismissInterruption() { pending = nil }
}
