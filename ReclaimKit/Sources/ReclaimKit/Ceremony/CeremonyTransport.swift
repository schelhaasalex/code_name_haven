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

public protocol CeremonyTransport: Sendable {
    func join(gathering: UUID) async throws
    func leave() async
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
    public func send(_ event: CeremonyEvent, from me: UUID) async {}
    public func events() -> AsyncStream<CeremonyEvent> { AsyncStream { _ in } }
}
