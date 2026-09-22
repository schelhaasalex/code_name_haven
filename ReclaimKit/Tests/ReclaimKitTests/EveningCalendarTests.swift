import XCTest
@testable import ReclaimKit

final class EveningCalendarTests: XCTestCase {

    private func calendar(_ timeZone: String = "UTC") -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZone)!
        return cal
    }

    private func date(_ iso: String, in timeZone: String = "UTC") -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: timeZone)!
        return f.date(from: "\(iso) 20:00")!
    }

    // MARK: - The week

    func testTheWeekStartsOnMonday() {
        // Thursday. Monday, Tuesday and Wednesday were docked.
        let days = EveningCalendar.week(
            evenings: ["2026-09-21", "2026-09-22", "2026-09-23"],
            today: date("2026-09-24"),
            calendar: calendar())
        XCTAssertEqual(days, [.docked, .docked, .docked, .missed, .future, .future, .future])
    }

    /// Sunday is the last square, not the first. Getting this wrong shifts
    /// every dot by one and is invisible unless the week is asserted whole.
    func testSundayEndsTheWeek() {
        let days = EveningCalendar.week(
            evenings: ["2026-09-13", "2026-09-20"],
            today: date("2026-09-20"),
            calendar: calendar())
        XCTAssertEqual(days, [.missed, .missed, .missed, .missed, .missed, .missed, .docked])
    }

    /// A day that hasn't happened is not a day you missed. The product never
    /// shows absence, and an outlined future dot is the whole difference.
    func testLaterThisWeekIsFutureNotMissed() {
        let days = EveningCalendar.week(
            evenings: ["2026-09-14"], today: date("2026-09-21"), calendar: calendar())
        XCTAssertEqual(days, [.missed, .future, .future, .future, .future, .future, .future])
        XCTAssertEqual(EveningCalendar.count(days), 0)
    }

    /// Day one: no evenings yet, so nothing has been missed — not today, not
    /// the four weeks before the app was installed.
    func testNothingIsMissedBeforeTheFirstEvening() {
        let week = EveningCalendar.week(evenings: [], today: date("2026-09-24"), calendar: calendar())
        XCTAssertEqual(week, [.before, .before, .before, .before, .future, .future, .future])
        let grid = EveningCalendar.grid(evenings: [], weeks: 4, today: date("2026-09-24"), calendar: calendar())
        XCTAssertFalse(grid.contains(.missed), "a first-day grid must not be four weeks of misses")
    }

    /// First evening on Wednesday: Monday and Tuesday came before it, Thursday
    /// (today, nothing yet) comes after it and can be missed.
    func testOnlyDaysAfterTheFirstEveningCanBeMissed() {
        let days = EveningCalendar.week(
            evenings: ["2026-09-23"], today: date("2026-09-24"), calendar: calendar())
        XCTAssertEqual(days, [.before, .before, .docked, .missed, .future, .future, .future])
    }

    func testTheWeekCrossesAMonthBoundary() {
        // Tuesday 1 September; the week runs from Monday 31 August.
        let days = EveningCalendar.week(
            evenings: ["2026-08-31", "2026-09-01"],
            today: date("2026-09-01"),
            calendar: calendar())
        XCTAssertEqual(Array(days.prefix(2)), [.docked, .docked])
    }

    /// `local_date` is the date in the PERSON'S timezone. Formatting the key in
    /// UTC instead lands every dot a day early east of Greenwich — and only
    /// there, which is how it would have shipped.
    func testEveningKeysUseTheDeviceTimezoneNotUTC() {
        let auckland = "Pacific/Auckland"   // UTC+12, so local midnight is the day before in UTC
        let days = EveningCalendar.week(
            evenings: ["2026-09-21"],
            today: date("2026-09-21", in: auckland),
            calendar: calendar(auckland))
        XCTAssertEqual(days.first, .docked)
        XCTAssertEqual(EveningCalendar.count(days), 1)
    }

    /// Five people at one dinner is one evening — the set is dates, not
    /// sessions, so nothing here can scale with household size.
    func testCountIsOverDistinctDates() {
        let days = EveningCalendar.week(
            evenings: ["2026-09-21", "2026-09-22"],
            today: date("2026-09-24"),
            calendar: calendar())
        XCTAssertEqual(EveningCalendar.count(days), 2)
    }

    // MARK: - The grid

    func testTheGridIsWholeWeeksEndingWithThisOne() {
        let today = date("2026-09-24")   // Thursday
        let grid = EveningCalendar.grid(
            evenings: ["2026-09-21", "2026-09-03"],
            weeks: 4, today: today, calendar: calendar())
        XCTAssertEqual(grid.count, 28)

        // The last row is the same seven days as the dot week on Home, so the
        // columns of the grid are weekdays.
        let week = EveningCalendar.week(
            evenings: ["2026-09-21", "2026-09-03"], today: today, calendar: calendar())
        XCTAssertEqual(Array(grid.suffix(7)), week)

        // 3 September is a Thursday three weeks back: row 1, column 4.
        XCTAssertEqual(grid[3], .docked)
        XCTAssertEqual(EveningCalendar.count(grid), 2)
    }

    func testTheGridOutlinesTheRestOfThisWeek() {
        let grid = EveningCalendar.grid(
            evenings: [], weeks: 4, today: date("2026-09-21"), calendar: calendar())
        XCTAssertEqual(Array(grid.suffix(6)),
                       Array(repeating: EveningCalendar.Day.future, count: 6))
        XCTAssertFalse(grid.dropLast(7).contains(.future))
    }

    func testTheGridTakesAnyNumberOfWeeks() {
        for weeks in 1...12 {
            XCTAssertEqual(
                EveningCalendar.grid(evenings: [], weeks: weeks,
                                     today: date("2026-09-24"), calendar: calendar()).count,
                weeks * 7)
        }
    }
}
