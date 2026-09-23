import XCTest
@testable import ReclaimKit

final class EveningLandingTests: XCTestCase {

    private let june = EveningTotal(count: 26, first: "2026-06-03")

    func testAQualifyingEveningLands() {
        let l = EveningLanding(total: june, known: ["2026-09-21"], localDate: "2026-09-23", minutes: 90)
        XCTAssertTrue(l.lands)
        XCTAssertEqual(l.evenings, 27)
        XCTAssertEqual(l.before, .init(count: 27, tonight: .waiting))
        XCTAssertEqual(l.after, .init(count: 27, tonight: .counted))
        XCTAssertEqual(l.since, "2026-06-03")
    }

    /// Under fifteen minutes it's kept, not counted: the dot stays an outline
    /// and the number doesn't move.
    func testAShortOneLandsNothing() {
        let l = EveningLanding(total: june, known: [], localDate: "2026-09-23", minutes: 14)
        XCTAssertFalse(l.lands)
        XCTAssertEqual(l.evenings, 26)
        XCTAssertEqual(l.after, l.before)
        XCTAssertEqual(l.after.tonight, .waiting)
    }

    /// Fifteen exactly counts, matching `app.qualifying_minutes()`.
    func testFifteenIsEnough() {
        XCTAssertTrue(EveningLanding(total: june, known: [], localDate: "2026-09-23", minutes: 15).lands)
    }

    /// A second evening the same day is one evening: no new dot, no outline,
    /// nothing animates.
    func testTheSameDayTwiceLandsOnce() {
        let l = EveningLanding(total: june, known: ["2026-09-23"], localDate: "2026-09-23", minutes: 90)
        XCTAssertFalse(l.lands)
        XCTAssertEqual(l.evenings, 26)
        XCTAssertEqual(l.before, .init(count: 26, tonight: .counted))
        XCTAssertEqual(l.after, l.before)
    }

    /// The very first evening is its own "since".
    func testTheFirstEveningIsItsOwnSince() {
        let l = EveningLanding(total: .zero, known: [], localDate: "2026-09-23", minutes: 40)
        XCTAssertEqual(l.evenings, 1)
        XCTAssertEqual(l.since, "2026-09-23")
        XCTAssertEqual(l.after, .init(count: 1, tonight: .counted))
    }

    /// And a first that's too short has no since at all — there isn't one yet.
    func testAShortFirstHasNoSince() {
        let l = EveningLanding(total: .zero, known: [], localDate: "2026-09-23", minutes: 5)
        XCTAssertEqual(l.evenings, 0)
        XCTAssertNil(l.since)
    }

    // MARK: - Not knowing

    /// The failure this guards: `my_evenings` doesn't answer, the app reads
    /// the silence as zero, and the evening that should have been somebody's
    /// twenty-seventh is announced as their first.
    func testAnUnansweredTotalIsNotZeroEvenings() {
        let landing = EveningLanding(total: nil, known: [], localDate: "2026-09-23", minutes: 90)
        XCTAssertFalse(landing.known)
        XCTAssertTrue(landing.lands, "the evening still counted — only the totals are unknown")
    }

    func testAnAnsweredTotalOfZeroIsKnown() {
        let landing = EveningLanding(total: .zero, known: [], localDate: "2026-09-23", minutes: 90)
        XCTAssertTrue(landing.known, "a real zero is a fact, and screen 8 may say it")
        XCTAssertEqual(landing.evenings, 1)
    }
}
