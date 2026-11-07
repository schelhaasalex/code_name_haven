import XCTest
@testable import ReclaimKit

final class NoteTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTheFirstOfAnyNoteGoes() {
        for note in Note.allCases { XCTAssertTrue(note.due(last: nil, at: now)) }
    }

    /// Something that happened is worth hearing every time it happens.
    func testWhatHappenedGoesEveryTime() {
        XCTAssertTrue(Note.pairNotHeard.due(last: now, at: now))
        XCTAssertTrue(Note.dockFailed.due(last: now, at: now))
    }

    /// Bluetooth being off on Tuesday is one fact, not one per launch.
    func testAStateGoesOnceADay() {
        XCTAssertFalse(Note.bluetoothOff.due(last: now, at: now.addingTimeInterval(3600)))
        XCTAssertTrue(Note.bluetoothOff.due(last: now, at: now.addingTimeInterval(25 * 3600)))
    }

    /// A phone reconnects all evening; the box only needs to be heard hourly
    /// — unless it has restarted, which is the news.
    func testAHelloGoesHourlyOrOnARestart() {
        let soon = now.addingTimeInterval(600)
        XCTAssertFalse(Note.boxHello.due(last: now, at: soon, bootsThen: 4, bootsNow: 4))
        XCTAssertTrue(Note.boxHello.due(last: now, at: soon, bootsThen: 4, bootsNow: 5))
        XCTAssertTrue(Note.boxHello.due(last: now, at: now.addingTimeInterval(3600), bootsThen: 4, bootsNow: 4))
    }

    func testAHelloIsReadAndAnEventIsNot() {
        let hello = Box.Hello(Data(#"{"v":1,"event":"hello","boots":7,"up":120,"reset":1,"fw":"0.4"}"#.utf8))
        XCTAssertEqual(hello?.boots, 7)
        XCTAssertEqual(hello?.detail, ["boots": "7", "up": "120", "reset": "1", "fw": "0.4"])
        XCTAssertNil(Box.Hello(Data(#"{"v":1,"slot":2,"event":"docked","t":5}"#.utf8)))
        XCTAssertNil(Box.Hello(Data(#"{"v":2,"event":"hello","boots":7,"up":1}"#.utf8)))
    }

    /// The names the database's check constraint allows (0021).
    func testTheKindsAreTheDatabases() {
        XCTAssertEqual(Set(Note.allCases.map(\.rawValue)),
                       ["paired", "pair_not_heard", "dock_failed", "camera_denied",
                        "bluetooth_off", "activities_off", "box_hello"])
    }
}
