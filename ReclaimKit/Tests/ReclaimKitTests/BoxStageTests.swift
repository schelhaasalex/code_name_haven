import XCTest
@testable import ReclaimKit

final class BoxStageTests: XCTestCase {

    /// The strings `app.place_stage` returns, exactly. A stage the app doesn't
    /// know reads as new rather than as nothing.
    func testEveryStageTheDatabaseNamesHasWords() {
        XCTAssertEqual(BoxStage.key("a landmark"), "place.stage.landmark")
        XCTAssertEqual(BoxStage.key("a reclaim house"), "place.stage.house")
        XCTAssertEqual(BoxStage.key("a regular table"), "place.stage.regular")
        XCTAssertEqual(BoxStage.key("new here"), "place.stage.new")
        XCTAssertEqual(BoxStage.key("something later"), "place.stage.new")
    }
}
