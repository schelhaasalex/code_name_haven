import XCTest
@testable import ReclaimKit

final class EveningMarkLayoutTests: XCTestCase {

    /// The first evening you ever had is the middle of the mark.
    func testTheFirstIsTheCentre() {
        let first = EveningMarkLayout.stars(1, seed: 7)[0]
        XCTAssertEqual(first.x, 0)
        XCTAssertEqual(first.y, 0)
    }

    func testOneStarPerEvening() {
        XCTAssertEqual(EveningMarkLayout.stars(27, seed: 7).count, 27)
        XCTAssertEqual(EveningMarkLayout.stars(365, seed: 7).count, 365)
    }

    /// A star never moves: more evenings is the same sky from further back,
    /// so every star keeps its place relative to the others.
    func testAStarKeepsItsPlace() {
        let week = EveningMarkLayout.stars(7, seed: 7)
        let year = EveningMarkLayout.stars(365, seed: 7)
        let zoom = (week[6].x * week[6].x + week[6].y * week[6].y).squareRoot()
            / (year[6].x * year[6].x + year[6].y * year[6].y).squareRoot()
        for i in 1..<7 {
            XCTAssertEqual(week[i].x, year[i].x * zoom, accuracy: 1e-9)
            XCTAssertEqual(week[i].y, year[i].y * zoom, accuracy: 1e-9)
            XCTAssertEqual(week[i].size, year[i].size)
        }
    }

    /// Scattered, but never two stars on top of each other.
    func testNoTwoStarsTouch() {
        let sky = (0..<365).map { EveningMarkLayout.place($0, seed: 7) }
        for i in sky.indices { for j in sky.indices where j > i {
            let d = ((sky[i].x - sky[j].x) * (sky[i].x - sky[j].x) + (sky[i].y - sky[j].y) * (sky[i].y - sky[j].y)).squareRoot()
            XCTAssertGreaterThan(d, 0.45, "stars \(i) and \(j)")
        } }
    }

    /// Each account's sky is its own, and the same every time it's drawn.
    func testASkyIsItsOwnersAndAlwaysTheSame() {
        let account = UUID(uuidString: "b6d45234-0b87-4046-a800-6a191d92b823")
        let seed = EveningMarkLayout.seed(account)
        XCTAssertEqual(EveningMarkLayout.stars(30, seed: seed), EveningMarkLayout.stars(30, seed: seed))
        XCTAssertNotEqual(EveningMarkLayout.stars(30, seed: seed), EveningMarkLayout.stars(30, seed: seed &+ 1))
        XCTAssertEqual(seed, EveningMarkLayout.seed(account))
    }

    /// Home the morning after: today waits as an outline beside every evening
    /// so far; once it counts, it is the newest of them, filled.
    func testHomeShowsTodayWaitingThenCounted() {
        XCTAssertEqual(EveningMarkLayout.today(total: 31, counted: false), .init(count: 32, tonight: .waiting))
        XCTAssertEqual(EveningMarkLayout.today(total: 32, counted: true), .init(count: 32, tonight: .counted))
        XCTAssertEqual(EveningMarkLayout.today(total: 0, counted: false), .init(count: 1, tonight: .waiting),
                       "before the first evening, one dot waiting")
    }

    func testTheMarkIsBounded() {
        XCTAssertEqual(EveningMarkLayout.stars(5000, seed: 7).count, EveningMarkLayout.capacity)
        XCTAssertEqual(EveningMarkLayout(count: 5000, tonight: .counted).drawn, EveningMarkLayout.capacity)
    }

    /// Every star fits inside the mark, and the outermost reaches its edge.
    func testEveryStarIsInside() {
        let reach = EveningMarkLayout.stars(91, seed: 7).map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }
        XCTAssertLessThanOrEqual(reach.max() ?? 0, 1.000_001)
        XCTAssertEqual(reach.max() ?? 0, 1, accuracy: 1e-9)
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
