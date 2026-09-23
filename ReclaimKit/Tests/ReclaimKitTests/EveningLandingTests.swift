import XCTest
@testable import ReclaimKit

final class EveningLandingTests: XCTestCase {

    func testAQualifyingEveningLandsTonight() {
        let l = EveningLanding(known: ["2026-09-21"], localDate: "2026-09-23", minutes: 40)
        XCTAssertEqual(l.tonight, "2026-09-23")
        XCTAssertEqual(l.after, ["2026-09-21", "2026-09-23"])
        XCTAssertTrue(l.qualifies)
    }

    /// Under fifteen minutes it's kept, not counted — so no dot fills.
    func testAShortOneLandsNothing() {
        let l = EveningLanding(known: [], localDate: "2026-09-23", minutes: 14)
        XCTAssertNil(l.tonight)
        XCTAssertEqual(l.after, l.before)
        XCTAssertFalse(l.qualifies)
    }

    /// Fifteen exactly counts, matching `app.qualifying_minutes()`.
    func testFifteenIsEnough() {
        XCTAssertEqual(EveningLanding(known: [], localDate: "2026-09-23", minutes: 15).tonight,
                       "2026-09-23")
    }

    /// A second evening the same day is one evening: nothing new lands, and
    /// the screen mustn't animate a dot that was already filled.
    func testTheSameDayTwiceLandsOnce() {
        let l = EveningLanding(known: ["2026-09-23"], localDate: "2026-09-23", minutes: 90)
        XCTAssertNil(l.tonight)
        XCTAssertTrue(l.qualifies)
        XCTAssertEqual(l.after, ["2026-09-23"])
    }

    func testTheCountEndsOnWhatWasCredited() {
        XCTAssertEqual(EveningLanding.counts(to: 134).last, 134)
        XCTAssertEqual(EveningLanding.counts(to: 134).count, 24)
        XCTAssertEqual(EveningLanding.counts(to: 5), [1, 2, 3, 4, 5])
        XCTAssertEqual(EveningLanding.counts(to: 0), [0])
    }

    /// The count only goes up — here too.
    func testTheCountNeverGoesDown() {
        let c = EveningLanding.counts(to: 241)
        XCTAssertEqual(c, c.sorted())
    }
}
