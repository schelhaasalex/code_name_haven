import XCTest
@testable import ReclaimKit

final class NudgeScheduleTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Nothing to go on, no time: the offer isn't made and nothing is planned.
    func testNoEveningsNoTime() {
        XCTAssertNil(NudgeSchedule.minute(of: [], calendar: calendar))
    }

    /// The first day: fifteen minutes before that evening, which is why the
    /// offer can say "around when your phone went in today" and be true.
    func testTheFirstDayIsItsOwnTime() {
        XCTAssertEqual(NudgeSchedule.minute(of: [at(11, 18, 55)], calendar: calendar), 18 * 60 + 40)
    }

    /// The median of the days, each day's first time only, rounded to five.
    func testTheMedianOfEachDaysFirstTime() {
        let starts = [at(2, 18, 0), at(3, 19, 2), at(3, 21, 30), at(4, 19, 0), at(5, 22, 0)]
        // first of each day: 18:00, 19:02, 19:00, 22:00 → lower median 19:00 → 18:45
        XCTAssertEqual(NudgeSchedule.minute(of: starts, calendar: calendar), 18 * 60 + 45)
    }

    /// Only the most recent fourteen days that counted.
    func testOnlyRecentDaysCount() {
        let old = (1...10).map { at($0, 8, 0, month: 9) }
        let lately = (1...14).map { at($0, 19, 0) }
        XCTAssertEqual(NudgeSchedule.minute(of: old + lately, calendar: calendar), 18 * 60 + 45)
    }

    /// Never before seven, never after a quarter to ten — and a phone in after
    /// midnight is late at night, not early in the morning.
    func testWakingHoursHold() {
        XCTAssertEqual(NudgeSchedule.minute(of: [at(11, 6, 0)], calendar: calendar), NudgeSchedule.earliest)
        XCTAssertEqual(NudgeSchedule.minute(of: [at(11, 23, 30)], calendar: calendar), NudgeSchedule.latest)
        XCTAssertEqual(NudgeSchedule.minute(of: [at(11, 0, 30)], calendar: calendar), NudgeSchedule.latest)
    }

    /// A week ahead, today included while its moment is still to come.
    func testAWeekAhead() {
        let dates = NudgeSchedule.dates(at: 18 * 60 + 40, from: at(11, 9, 0), todayCounts: false, calendar: calendar)
        XCTAssertEqual(dates.count, NudgeSchedule.ahead)
        XCTAssertEqual(dates.first, at(11, 18, 40))
        XCTAssertEqual(dates.last, at(17, 18, 40))
    }

    /// Never on a day that already counts.
    func testNotTodayOnceItCounts() {
        let dates = NudgeSchedule.dates(at: 18 * 60 + 40, from: at(11, 9, 0), todayCounts: true, calendar: calendar)
        XCTAssertEqual(dates.first, at(12, 18, 40))
        XCTAssertEqual(dates.count, NudgeSchedule.ahead - 1)
    }

    /// Nor after today's moment has passed.
    func testNotTodayOnceItsTimeHasGone() {
        let dates = NudgeSchedule.dates(at: 18 * 60 + 40, from: at(11, 20, 0), todayCounts: false, calendar: calendar)
        XCTAssertEqual(dates.first, at(12, 18, 40))
    }

    /// The clocks change in New York on 1 November 2026; 6:40 stays 6:40.
    func testWallClockAcrossTheChange() {
        let dates = NudgeSchedule.dates(at: 18 * 60 + 40, from: at(30, 9, 0, month: 10), todayCounts: false,
                                        calendar: calendar)
        for d in dates {
            XCTAssertEqual(calendar.component(.hour, from: d), 18)
            XCTAssertEqual(calendar.component(.minute, from: d), 40)
        }
    }

    /// Two lines take turns, day by day.
    func testLinesTakeTurns() {
        let lines = ["one", "two"]
        let a = NudgeSchedule.line(lines, on: at(11, 18, 40), calendar: calendar)
        let b = NudgeSchedule.line(lines, on: at(12, 18, 40), calendar: calendar)
        XCTAssertNotNil(a)
        XCTAssertNotEqual(a, b)
        XCTAssertNil(NudgeSchedule.line([], on: .now, calendar: calendar))
    }
}
