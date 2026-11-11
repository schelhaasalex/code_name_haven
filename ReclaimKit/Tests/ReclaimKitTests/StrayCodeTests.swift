import XCTest
@testable import ReclaimKit

final class StrayCodeTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    /// The camera's reports while a code is held up: every tenth of a second.
    private func held(_ code: inout StrayCode, from start: TimeInterval, for seconds: TimeInterval) {
        var s = start
        while s <= start + seconds {
            code.seen(at: t0 + s)
            s += 0.1
        }
    }

    func testNothingSeenSaysNothing() {
        XCTAssertFalse(StrayCode().showing(at: t0))
    }

    /// Swept past on the way to the card: not worth a word.
    func testAGlanceIsNotMentioned() {
        var code = StrayCode()
        held(&code, from: 0, for: 0.4)
        XCTAssertFalse(code.showing(at: t0 + 0.5))
    }

    /// Held up for a second: it's said.
    func testHeldUpItIsSaid() {
        var code = StrayCode()
        held(&code, from: 0, for: 1.2)
        XCTAssertTrue(code.showing(at: t0 + 1.2))
    }

    /// Taken away, the line stays a moment, then goes back.
    func testItGoesBackOnceTheCodeHasGone() {
        var code = StrayCode()
        held(&code, from: 0, for: 1.2)
        XCTAssertTrue(code.showing(at: t0 + 2.5))
        XCTAssertFalse(code.showing(at: t0 + 4))
    }

    /// Two glances a while apart aren't one long look.
    func testGlancesDoNotAddUp() {
        var code = StrayCode()
        held(&code, from: 0, for: 0.6)
        held(&code, from: 2, for: 0.6)
        XCTAssertFalse(code.showing(at: t0 + 2.6))
    }
}
