import Foundation

/// The network half of an evening, run in order and off to the side.
///
/// Rule 7: the ritual never waits on a network call. A Realtime subscribe
/// that is refused or unreachable is retried by the SDK — five attempts, ten
/// seconds each — so awaiting one inline meant the chime, the sensor and the
/// Live Activity could wait a minute behind a channel. Here nothing is awaited
/// by the caller: each request is queued and returns at once.
///
/// Queued rather than fired, because the transport holds one channel. Two
/// joins racing — set it down, end, set it down again while the first is still
/// retrying — could leave the old channel open or tear down the new one. Steps
/// run one at a time, a newer request supersedes an older one, and a join that
/// lands after it was superseded leaves again at once.
@MainActor
public final class CeremonyLink {

    private let transport: any CeremonyTransport
    private var tail: Task<Void, Never>?
    private var generation = 0

    public init(transport: any CeremonyTransport) { self.transport = transport }

    /// Join the gathering's channel. `docked` and `invitation` go out only
    /// once it is joined — before that there is nowhere to send them.
    public func connect(gathering: UUID, me: UUID?,
                        docked: Date? = nil, invitation: Invitation? = nil) {
        let mine = supersede()
        enqueue { [transport] in
            await transport.stopWatching()
            guard self.generation == mine else { return }
            do { try await transport.join(gathering: gathering) } catch { return }
            // Ended, or started again, while the join was in flight.
            guard self.generation == mine, !Task.isCancelled else {
                await transport.leave()
                return
            }
            if let docked, let me { await transport.send(.docked(at: docked), from: me) }
            if let invitation { await transport.announce(invitation) }
        }
    }

    public func disconnect() {
        _ = supersede()
        enqueue { [transport] in await transport.leave() }
    }

    /// Screen 4's listening, between evenings. Skipped if an evening started
    /// while it was waiting its turn.
    public func watch(places: [UUID]) {
        let mine = generation
        enqueue { [transport] in
            guard self.generation == mine else { return }
            await transport.watch(places: places)
        }
    }

    /// Resolves once everything queued so far has run.
    public func settled() async { await tail?.value }

    private func supersede() -> Int {
        generation += 1
        tail?.cancel()
        return generation
    }

    private func enqueue(_ step: @escaping @MainActor () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await step()
        }
    }
}
