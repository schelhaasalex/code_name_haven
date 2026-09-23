import XCTest
@testable import ReclaimKit

final class EveningMarkLayoutTests: XCTestCase {

    /// The first evening you ever had is the middle of the mark.
    func testTheFirstIsTheCentre() {
        XCTAssertEqual(EveningMarkLayout.points(1), [.init(x: 0, y: 0)])
    }

    func testOneDotPerEvening() {
        XCTAssertEqual(EveningMarkLayout.points(27).count, 27)
        XCTAssertEqual(EveningMarkLayout.points(91).count, 91)
    }

    /// Five rings hold 91. Past that it's bounded, and the words carry the rest.
    func testTheMarkIsBounded() {
        XCTAssertEqual(EveningMarkLayout.points(200).count, EveningMarkLayout.capacity)
        XCTAssertEqual(EveningMarkLayout(count: 200, tonight: .counted).drawn, 91)
    }

    /// Every dot fits inside the mark.
    func testEveryDotIsInside() {
        for p in EveningMarkLayout.points(91) {
            XCTAssertLessThanOrEqual((p.x * p.x + p.y * p.y).squareRoot(), 1.000_001)
        }
    }

    /// Before fifteen minutes tonight is an outline; after, it's filled.
    func testTonightFillsAtFifteenMinutes() {
        XCTAssertEqual(EveningMarkLayout.during(total: 26, alreadyCounted: false, elapsed: 14 * 60 + 59),
                       .init(count: 27, tonight: .waiting))
        XCTAssertEqual(EveningMarkLayout.during(total: 26, alreadyCounted: false, elapsed: 15 * 60),
                       .init(count: 27, tonight: .counted))
    }

    /// Today already counted: tonight's dot is that one, filled from the
    /// start — never a second dot for the same day.
    func testASecondEveningTheSameDayIsTheSameDot() {
        XCTAssertEqual(EveningMarkLayout.during(total: 26, alreadyCounted: true, elapsed: 0),
                       .init(count: 26, tonight: .counted))
    }

    /// There is always at least tonight's dot to draw.
    func testNeverEmpty() {
        XCTAssertEqual(EveningMarkLayout(count: 0, tonight: .waiting).count, 1)
    }
}
