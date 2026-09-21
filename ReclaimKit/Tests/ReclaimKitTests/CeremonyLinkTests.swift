import XCTest
@testable import ReclaimKit

/// A transport whose joins can be held open, the way a refused or unreachable
/// Realtime subscribe holds for a minute, so the order around it can be seen.
private actor HeldTransport: CeremonyTransport {
    private(set) var log: [String] = []
    private var held: [CheckedContinuation<Bool, Never>] = []
    private let holding: Bool

    init(holding: Bool) { self.holding = holding }

    struct Refused: Error {}

    func join(gathering: UUID) async throws {
        log.append("join")
        guard holding else { return }
        guard await withCheckedContinuation({ held.append($0) }) else { throw Refused() }
    }

    /// Whether a join is in flight, waiting a bounded while for one to start —
    /// bounded so a wrong expectation fails the test instead of hanging it.
    func joinStarted() async -> Bool {
        for _ in 0..<10_000 where held.isEmpty { await Task.yield() }
        return !held.isEmpty
    }

    /// Let the oldest held join finish. False if none ever started.
    @discardableResult
    func finishJoin(succeeding: Bool = true) async -> Bool {
        guard await joinStarted() else { return false }
        held.removeFirst().resume(returning: succeeding)
        return true
    }

    func leave() async { log.append("leave") }
    func watch(places: [UUID]) async { log.append("watch") }
    func stopWatching() async { log.append("stopWatching") }
    func announce(_ invitation: Invitation) async { log.append("announce") }
    func send(_ event: CeremonyEvent, from me: UUID) async { log.append("send") }
    nonisolated func invitations() -> AsyncStream<Invitation> { AsyncStream { _ in } }
    nonisolated func events() -> AsyncStream<CeremonyEvent> { AsyncStream { _ in } }
}

@MainActor
final class CeremonyLinkTests: XCTestCase {

    private let me = UUID()
    private let at = Date(timeIntervalSince1970: 1_790_000_000)
    private var invitation: Invitation {
        Invitation(gathering: UUID(), place: UUID(), name: "Alex", count: 1, at: at)
    }

    /// The whole point: connecting returns while the join is still out.
    func testConnectingDoesNotWaitForTheChannel() async {
        let transport = HeldTransport(holding: true)
        let link = CeremonyLink(transport: transport)

        link.connect(gathering: UUID(), me: me, docked: at, invitation: invitation)
        // Reaching this line with the join held is the assertion.
        let started = await transport.joinStarted()
        XCTAssertTrue(started)
        let before = await transport.log
        XCTAssertFalse(before.contains("send"), "nothing goes out before the channel is up")
        await transport.finishJoin()
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["stopWatching", "join", "send", "announce"])
    }

    func testNothingIsSentIfTheJoinFails() async {
        let transport = HeldTransport(holding: true)
        let link = CeremonyLink(transport: transport)

        link.connect(gathering: UUID(), me: me, docked: at, invitation: invitation)
        await transport.finishJoin(succeeding: false)
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["stopWatching", "join"])
    }

    /// Ended before the channel came up: it leaves as soon as it arrives, and
    /// nobody is told you docked.
    func testEndingWhileTheJoinIsOutLeavesWithoutSending() async {
        let transport = HeldTransport(holding: true)
        let link = CeremonyLink(transport: transport)

        link.connect(gathering: UUID(), me: me, docked: at, invitation: invitation)
        let started = await transport.joinStarted()
        XCTAssertTrue(started)
        link.disconnect()
        link.watch(places: [UUID()])
        await transport.finishJoin()
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["stopWatching", "join", "leave", "leave", "watch"])
        XCTAssertFalse(log.contains("send"))
    }

    /// Set it down, end, set it down again while the first join is still
    /// retrying. The second evening's channel is the one left standing.
    func testASecondEveningWaitsForTheFirstJoinAndWins() async {
        let transport = HeldTransport(holding: true)
        let link = CeremonyLink(transport: transport)

        link.connect(gathering: UUID(), me: me, docked: at)
        let started = await transport.joinStarted()
        XCTAssertTrue(started)
        link.disconnect()
        link.connect(gathering: UUID(), me: me, docked: at)
        let first = await transport.finishJoin()    // the first, now superseded
        let second = await transport.finishJoin()   // the second
        XCTAssertTrue(first && second)
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["stopWatching", "join", "leave", "leave",
                             "stopWatching", "join", "send"])
    }

    /// Ended before the join even began: it never starts.
    func testEndingBeforeTheJoinStartsSkipsIt() async {
        let transport = HeldTransport(holding: true)
        let link = CeremonyLink(transport: transport)

        link.connect(gathering: UUID(), me: me, docked: at)
        link.disconnect()
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["stopWatching", "leave"])
    }

    /// Screen 4 waits its turn, and doesn't start listening at a table you
    /// have since sat down at.
    func testWatchingIsSkippedOnceAnEveningHasStarted() async {
        let transport = HeldTransport(holding: false)
        let link = CeremonyLink(transport: transport)

        link.watch(places: [UUID()])
        link.connect(gathering: UUID(), me: me)
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["stopWatching", "join"])
    }

    func testWatchingBetweenEveningsRuns() async {
        let transport = HeldTransport(holding: false)
        let link = CeremonyLink(transport: transport)

        link.watch(places: [UUID()])
        await link.settled()

        let log = await transport.log
        XCTAssertEqual(log, ["watch"])
    }
}
