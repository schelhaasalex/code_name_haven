import XCTest
@testable import ReclaimKit

final class BoxStageTests: XCTestCase {

    /// The strings `app.place_stage` returns, exactly. A stage the app doesn't
    /// know yet reads as on its way rather than as nothing.
    func testEveryStageTheDatabaseNamesHasWords() {
        XCTAssertEqual(BoxStage.key("part of the house"), "place.stage.house")
        XCTAssertEqual(BoxStage.key("seasoned"), "place.stage.seasoned")
        XCTAssertEqual(BoxStage.key("settled in"), "place.stage.settled")
        XCTAssertEqual(BoxStage.key("broken in"), "place.stage.broken")
        XCTAssertEqual(BoxStage.key("on its way"), "place.stage.way")
        XCTAssertEqual(BoxStage.key("something later"), "place.stage.way")
    }

    func testAStageIsReachedOnItsDay() {
        XCTAssertEqual(BoxStage.reached(evenings: 0), 0)
        XCTAssertEqual(BoxStage.reached(evenings: 6), 0)
        XCTAssertEqual(BoxStage.reached(evenings: 7), 1)
        XCTAssertEqual(BoxStage.reached(evenings: 30), 2)
        XCTAssertEqual(BoxStage.reached(evenings: 364), 3)
        XCTAssertEqual(BoxStage.reached(evenings: 365), 4)
    }

    /// Marks evenly spaced; between two, the way along it.
    func testTheTrackFillsBetweenMarks() {
        XCTAssertEqual(BoxStage.position(evenings: 0), 0)
        XCTAssertEqual(BoxStage.position(evenings: 7), 0.25)
        XCTAssertEqual(BoxStage.position(evenings: 65), 0.625, accuracy: 0.0001)
        XCTAssertEqual(BoxStage.position(evenings: 365), 1)
        XCTAssertEqual(BoxStage.position(evenings: 2000), 1)
    }

    /// Forward only: one more day never moves the mark back.
    func testTheTrackOnlyMovesForward() {
        for d in 0..<400 {
            XCTAssertLessThanOrEqual(BoxStage.position(evenings: d), BoxStage.position(evenings: d + 1))
        }
    }
}
