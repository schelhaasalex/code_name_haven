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
/// The wire format, and the two ways it was silently wrong, are in
/// `CeremonyWire`. What's left here is channels: joining, leaving, and making
/// sure a failed subscribe is known about rather than swallowed.
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

    public func join(gathering: UUID) async throws {
        await leave()
        let ch = client.channel("gathering:\(gathering.uuidString)")
        let stream = ch.broadcastStream(event: "ceremony")
        do {
            try await ch.subscribeWithError()
        } catch {
            await client.removeChannel(ch)
            throw error
        }
        channel = ch

        pump = Task { [weak self] in
            for await envelope in stream {
                guard let self else { return }
                guard let p = CeremonyWire.unwrap(envelope, as: CeremonyWire.Payload.self)
                else { continue }
                await self.deliver(p)
            }
        }
    }

    private func deliver(_ p: CeremonyWire.Payload) {
        guard let event = CeremonyWire.event(from: p, me: me) else { return }
        continuation?.yield(event)
    }

    /// Removed rather than unsubscribed: the client caches channels by topic,
    /// so an unsubscribed one would be handed back on the next join.
    public func leave() async {
        pump?.cancel(); pump = nil
        if let channel { await client.removeChannel(channel) }
        channel = nil
    }

    public func send(_ event: CeremonyEvent, from me: UUID) async {
        self.me = me
        guard let channel else { return }
        try? await channel.broadcast(event: "ceremony",
                                     message: CeremonyWire.payload(for: event, from: me))
    }

    // MARK: - Invitations

    /// A place whose channel won't subscribe is skipped, not retried: screen 4
    /// is an offer, and nothing is gated on it arriving.
    public func watch(places: [UUID]) async {
        await stopWatching()
        for place in places {
            guard let ch = await subscribed("place:\(place.uuidString)", listening: true)
            else { continue }
            let stream = ch.stream
            placeChannels[place] = ch.channel
            placePumps[place] = Task { [weak self] in
                for await envelope in stream {
                    guard let self else { return }
                    guard let invitation = CeremonyWire.unwrap(envelope, as: Invitation.self)
                    else { continue }
                    await self.deliver(invitation)
                }
            }
        }
    }

    public func stopWatching() async {
        for pump in placePumps.values { pump.cancel() }
        placePumps.removeAll()
        for channel in placeChannels.values { await client.removeChannel(channel) }
        placeChannels.removeAll()
    }

    /// Subscribes if it has to: the announcer stops watching their places the
    /// moment their own session starts, and the announcement comes after.
    public func announce(_ invitation: Invitation) async {
        if placeChannels[invitation.place] == nil {
            guard let ch = await subscribed("place:\(invitation.place.uuidString)", listening: false)
            else { return }
            placeChannels[invitation.place] = ch.channel
        }
        try? await placeChannels[invitation.place]?.broadcast(event: "invitation",
                                                              message: invitation)
    }

    /// A subscribed channel, or nil. Listening means registering the stream
    /// first — callbacks added after subscribing are not guaranteed to fire.
    private func subscribed(_ topic: String, listening: Bool)
        async -> (channel: RealtimeChannelV2, stream: AsyncStream<JSONObject>)? {
        let ch = client.channel(topic)
        let stream = listening ? ch.broadcastStream(event: "invitation") : AsyncStream { $0.finish() }
        do {
            try await ch.subscribeWithError()
            return (ch, stream)
        } catch {
            await client.removeChannel(ch)
            return nil
        }
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
