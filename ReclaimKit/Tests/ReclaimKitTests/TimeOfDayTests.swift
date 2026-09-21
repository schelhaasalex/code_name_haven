import XCTest
@testable import ReclaimKit

final class TimeOfDayTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 21) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day,
                                           hour: hour, minute: minute))!
    }

    private func seconds(_ hour: Int, _ minute: Int = 0) -> TimeInterval {
        TimeInterval(hour * 3600 + minute * 60)
    }

    func testOneEveningIsItsOwnUsualTime() throws {
        let usual = try XCTUnwrap(TimeOfDay.usual(of: [at(19, 40)], calendar: calendar))
        XCTAssertEqual(usual, seconds(19, 40), accuracy: 1)
    }

    func testTheUsualTimeIsBetweenThem() throws {
        let usual = try XCTUnwrap(
            TimeOfDay.usual(of: [at(19), at(21)], calendar: calendar))
        XCTAssertEqual(usual, seconds(20), accuracy: 1)
    }

    /// The reason this isn't an average. Eleven at night and one in the morning
    /// are two hours apart; the mean of 82,800 and 3,600 seconds is midday,
    /// which would print "around 12:00" under a photograph of a dinner.
    func testLateAndEarlyMeetAtMidnightNotMidday() throws {
        let usual = try XCTUnwrap(
            TimeOfDay.usual(of: [at(23), at(1, 0, day: 22)], calendar: calendar))
        XCTAssertTrue(usual < 60 || usual > seconds(23, 59),
                      "expected around midnight, got \(usual)")
    }

    func testAnEveningHabitSurvivesAnOddOneOut() throws {
        let dinners = [at(19, 30), at(19, 50), at(20, 10), at(19, 40)]
        let usual = try XCTUnwrap(TimeOfDay.usual(of: dinners, calendar: calendar))
        XCTAssertEqual(usual, seconds(19, 47), accuracy: 120)
    }

    /// Two times exactly opposite each other have no usual hour between them,
    /// and picking one would be inventing a habit. The screen leaves the line
    /// out instead.
    func testNoUsualTimeWhenThereIsntOne() {
        XCTAssertNil(TimeOfDay.usual(of: [at(6), at(18)], calendar: calendar))
        XCTAssertNil(TimeOfDay.usual(of: [], calendar: calendar))
    }

    func testTheDayItHappenedDoesNotMatter() throws {
        let sameTimeDifferentDays = [at(20, day: 1), at(20, day: 14), at(20, day: 28)]
        let usual = try XCTUnwrap(
            TimeOfDay.usual(of: sameTimeDifferentDays, calendar: calendar))
        XCTAssertEqual(usual, seconds(20), accuracy: 1)
    }
}
