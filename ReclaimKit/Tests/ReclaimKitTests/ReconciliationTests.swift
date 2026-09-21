import XCTest
@testable import ReclaimKit

/// Coming back to the app: what it thinks is running, against what the
/// database says.
final class ReconciliationTests: XCTestCase {

    private struct Offline: Error {}

    private func session() -> Session {
        Session(id: UUID(), profileId: UUID(), gatheringId: UUID(),
                startedAt: Date(timeIntervalSince1970: 1_790_000_000), localDate: "2026-09-21")
    }

    /// The one that matters most: a failed read is not "nothing is running".
    func testAFailedReadChangesNothingMidEvening() {
        XCTAssertEqual(Reconciliation.between(running: session(), database: .failure(Offline())), .keep)
    }

    func testAFailedReadChangesNothingBetweenEvenings() {
        XCTAssertEqual(Reconciliation.between(running: nil, database: .failure(Offline())), .keep)
    }

    /// Not re-adopted: that restarted the Live Activity on every foreground.
    func testTheSameEveningIsRefreshedNotRestarted() {
        let s = session()
        XCTAssertEqual(Reconciliation.between(running: s, database: .success(s)), .refresh)
    }

    func testAnEveningEndedElsewhereEndsHere() {
        XCTAssertEqual(Reconciliation.between(running: session(), database: .success(nil)), .end)
    }

    func testAnEveningStartedElsewhereIsAdopted() {
        let found = session()
        XCTAssertEqual(Reconciliation.between(running: nil, database: .success(found)), .adopt(found))
    }

    /// Ended one, started another, all while the app was away.
    func testADifferentEveningReplacesTheOldOne() {
        let found = session()
        XCTAssertEqual(Reconciliation.between(running: session(), database: .success(found)), .adopt(found))
    }

    func testNothingRunningAnywhereIsIdle() {
        XCTAssertEqual(Reconciliation.between(running: nil, database: .success(nil)), .idle)
    }
}
