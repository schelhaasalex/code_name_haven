import Foundation
import Supabase

/// What a gathering broadcasts. Absolute state, never deltas.
public enum CeremonyEvent: Sendable, Equatable {
    /// Someone started or joined. `at` is the shared origin for everyone's timer.
    case docked(at: Date)
    /// One person's phone turned over, or back up.
    case faceDown(profile: UUID, down: Bool)
    /// One person ended theirs.
    case released(profile: UUID)
}

/// "Someone just set theirs down at a place you know."
///
/// Sent by the person who started it, carrying their own display name — they
/// know it, it is their row, and telling the table who you are is the point.
/// Nobody's name reaches anyone any other way: the RPC that returns members
/// checks that you are IN the gathering first.
public struct Invitation: Sendable, Equatable, Identifiable, Codable {
    public let gathering: UUID
    public let place: UUID
    public let name: String?
    /// How many are down, according to the person who sent it. The receiver
    /// cannot look this up — `gathering_members` checks membership first, and
    /// they aren't a member yet — so it is told rather than fetched, and it
    /// only ever counts people who HAVE set theirs down.
    public let count: Int
    public let at: Date

    public var id: UUID { gathering }

    public init(gathering: UUID, place: UUID, name: String?, count: Int, at: Date) {
        self.gathering = gathering; self.place = place; self.name = name
        self.count = count; self.at = at
    }
}

public protocol CeremonyTransport: Sendable {
    func join(gathering: UUID) async throws
    func leave() async

    /// Listened to while nothing is running, so one person setting theirs down
    /// can reach the other people who know the place. Screen 4.
    func watch(places: [UUID]) async
    func stopWatching() async
    func announce(_ invitation: Invitation) async
    func invitations() -> AsyncStream<Invitation>
    func send(_ event: CeremonyEvent, from me: UUID) async
    /// Delivered for every peer's event. Your own echoes are filtered out here,
    /// because the app renders your tap on send — waiting for the round trip
    /// would make the person who tapped the last to feel it.
    func events() -> AsyncStream<CeremonyEvent>
}

// ---------------------------------------------------------------------------

/// Supabase Realtime broadcast.
///
/// ⚠️ THIS FILE AND SupabaseRepository ARE THE TWO MOST LIKELY TO NEED SMALL
/// ADJUSTMENTS on the first build — they're the only places that touch
/// supabase-swift's API surface. Everything else is Foundation and SwiftUI.
/// The shapes to check are `client.channel(_:)`, `channel.broadcastStream(event:)`
/// and `channel.broadcast(event:message:)`.
public actor SupabaseCeremonyTransport: CeremonyTransport {

    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var pump: Task<Void, Never>?
    private var continuation: AsyncStream<CeremonyEvent>.Continuation?
    private var me: UUID?

    private var placeChannels: [UUID: RealtimeChannelV2] = [:]
    private var placePumps: [UUID: Task<Void, Never>] = [:]
    private var invitationStream: AsyncStream<Invitation>.Continuation?

    public init(client: SupabaseClient) { self.client = client }

    private struct Payload: Codable {
        var kind: String          // "docked" | "facedown" | "released"
        var sender: String
        var at: Double?
        var down: Bool?
    }

    public func join(gathering: UUID) async throws {
        await leave()
        let ch = client.channel("gathering:\(gathering.uuidString)")
        let stream = ch.broadcastStream(event: "ceremony")
        await ch.subscribe()
        channel = ch

        pump = Task { [weak self] in
            for await raw in stream {
                guard let self else { return }
                guard let data = try? JSONEncoder().encode(raw),
                      let p = try? JSONDecoder().decode(Payload.self, from: data)
                else { continue }
                await self.deliver(p)
            }
        }
    }

    private func deliver(_ p: Payload) {
        guard let sender = UUID(uuidString: p.sender), sender != me else { return }
        switch p.kind {
        case "docked":
            continuation?.yield(.docked(at: p.at.map { Date(timeIntervalSince1970: $0) } ?? .now))
        case "facedown":
            continuation?.yield(.faceDown(profile: sender, down: p.down ?? false))
        case "released":
            continuation?.yield(.released(profile: sender))
        default:
            break
        }
    }

    public func leave() async {
        pump?.cancel(); pump = nil
        if let channel { await channel.unsubscribe() }
        channel = nil
    }

    public func send(_ event: CeremonyEvent, from me: UUID) async {
        self.me = me
        guard let channel else { return }
        let p: Payload
        switch event {
        case .docked(let at):
            p = Payload(kind: "docked", sender: me.uuidString,
                        at: at.timeIntervalSince1970, down: nil)
        case .faceDown(_, let down):
            p = Payload(kind: "facedown", sender: me.uuidString, at: nil, down: down)
        case .released:
            p = Payload(kind: "released", sender: me.uuidString, at: nil, down: nil)
        }
        try? await channel.broadcast(event: "ceremony", message: p)
    }

    // MARK: - Invitations

    public func watch(places: [UUID]) async {
        await stopWatching()
        for place in places {
            let ch = client.channel("place:\(place.uuidString)")
            let stream = ch.broadcastStream(event: "invitation")
            await ch.subscribe()
            placeChannels[place] = ch
            placePumps[place] = Task { [weak self] in
                for await raw in stream {
                    guard let self else { return }
                    guard let data = try? JSONEncoder().encode(raw),
                          let invitation = try? JSONDecoder().decode(Invitation.self, from: data)
                    else { continue }
                    await self.deliver(invitation)
                }
            }
        }
    }

    public func stopWatching() async {
        for pump in placePumps.values { pump.cancel() }
        placePumps.removeAll()
        for channel in placeChannels.values { await channel.unsubscribe() }
        placeChannels.removeAll()
    }

    /// Subscribes if it has to: the announcer stops watching their places the
    /// moment their own session starts, and the announcement comes after.
    public func announce(_ invitation: Invitation) async {
        if placeChannels[invitation.place] == nil {
            let ch = client.channel("place:\(invitation.place.uuidString)")
            await ch.subscribe()
            placeChannels[invitation.place] = ch
        }
        try? await placeChannels[invitation.place]?.broadcast(event: "invitation",
                                                              message: invitation)
    }

    private func deliver(_ invitation: Invitation) {
        invitationStream?.yield(invitation)
    }

    public nonisolated func invitations() -> AsyncStream<Invitation> {
        AsyncStream { cont in
            Task { await self.attach(invitations: cont) }
        }
    }

    private func attach(invitations cont: AsyncStream<Invitation>.Continuation) {
        invitationStream = cont
    }

    public nonisolated func events() -> AsyncStream<CeremonyEvent> {
        AsyncStream { cont in
            Task { await self.attach(cont) }
        }
    }

    private func attach(_ cont: AsyncStream<CeremonyEvent>.Continuation) {
        continuation = cont
    }
}

// ---------------------------------------------------------------------------

/// For previews, tests, and the single-phone case. Does nothing, quietly.
public struct LocalCeremonyTransport: CeremonyTransport {
    public init() {}
    public func join(gathering: UUID) async throws {}
    public func leave() async {}
    public func watch(places: [UUID]) async {}
    public func stopWatching() async {}
    public func announce(_ invitation: Invitation) async {}
    public func invitations() -> AsyncStream<Invitation> { AsyncStream { _ in } }
    public func send(_ event: CeremonyEvent, from me: UUID) async {}
    public func events() -> AsyncStream<CeremonyEvent> { AsyncStream { _ in } }
}
