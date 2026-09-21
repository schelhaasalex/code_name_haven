import XCTest
@testable import ReclaimKit

/// These strings are read by a person, so a wrong plural or an off-by-one month
/// is a visible bug rather than an internal one.
final class FormattingTests: XCTestCase {

    func testCountIsSpelledOutThenNumeric() {
        XCTAssertEqual(Say.count(0), "Nobody")
        XCTAssertEqual(Say.count(1), "Just you")
        XCTAssertEqual(Say.count(3), "Three of you")
        XCTAssertEqual(Say.count(9), "Nine of you")
        XCTAssertEqual(Say.count(10), "10 of you")
    }

    /// The count comes from the database and can only go up, but nothing stops
    /// a decode giving a nonsense value, and it must not crash the index.
    func testCountSurvivesNonsense() {
        XCTAssertEqual(Say.count(-1), "-1 of you")
    }

    /// Monday 21 September 2026, in one fixed zone and language.
    private func monday(_ hour: Int, _ minute: Int = 0) -> (Date, Calendar) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        cal.locale = Locale(identifier: "en_US")
        let date = cal.date(from: DateComponents(year: 2026, month: 9, day: 21,
                                                 hour: hour, minute: minute))!
        return (date, cal)
    }

    func testPartOfDaySaysWhichDayItIs() {
        let (morning, cal) = monday(9)
        XCTAssertEqual(Say.partOfDay(morning, calendar: cal), "Monday morning")
        XCTAssertEqual(Say.partOfDay(monday(12).0, calendar: cal), "Monday afternoon")
        XCTAssertEqual(Say.partOfDay(monday(19, 30).0, calendar: cal), "Monday evening")
        XCTAssertEqual(Say.partOfDay(monday(23).0, calendar: cal), "Monday night")
    }

    /// One in the morning is still the night before — it belongs to the
    /// evening that started it, as `local_date` does.
    func testSmallHoursBelongToTheNightBefore() {
        let (early, cal) = monday(1)
        XCTAssertEqual(Say.partOfDay(early, calendar: cal), "Sunday night")
        XCTAssertEqual(Say.partOfDay(monday(5).0, calendar: cal), "Monday morning")
    }

    func testDurationNeverShowsAZeroHour() {
        XCTAssertEqual(Say.duration(minutes: 0), "0m")
        XCTAssertEqual(Say.duration(minutes: 48), "48m")
        XCTAssertEqual(Say.duration(minutes: 60), "1h")
        XCTAssertEqual(Say.duration(minutes: 134), "2h 14m")
        XCTAssertEqual(Say.duration(minutes: 180), "3h")
        XCTAssertFalse(Say.duration(minutes: 48).contains("0h"))
    }

    func testSpokenDurationReadsAsProse() {
        XCTAssertEqual(Say.spokenDuration(minutes: 0), "no minutes")
        XCTAssertEqual(Say.spokenDuration(minutes: 1), "a minute")
        XCTAssertEqual(Say.spokenDuration(minutes: 9), "nine minutes")
        XCTAssertEqual(Say.spokenDuration(minutes: 60), "an hour")
        XCTAssertEqual(Say.spokenDuration(minutes: 70), "an hour and ten")
        XCTAssertEqual(Say.spokenDuration(minutes: 120), "two hours")
        XCTAssertEqual(Say.spokenDuration(minutes: 134), "two hours and 14")
    }

    /// Who is here. There is deliberately no form of this that says how many
    /// people haven't arrived.
    func testNamesReadAsASentence() {
        XCTAssertEqual(Say.names([]), "")
        XCTAssertEqual(Say.names(["Maya"]), "Maya")
        XCTAssertEqual(Say.names(["Maya", "Dad"]), "Maya and Dad")
        XCTAssertEqual(Say.names(["Maya", "Dad", "Sam"]), "Maya, Dad and Sam")
        XCTAssertEqual(Say.names(["Maya", "Dad", "Sam", "Ellie"]),
                       "Maya, Dad, Sam and Ellie")
    }

    func testClockPadsSecondsAndFloorsAtZero() {
        XCTAssertEqual(Say.clock(0), "0:00")
        XCTAssertEqual(Say.clock(9), "0:09")
        XCTAssertEqual(Say.clock(61), "1:01")
        XCTAssertEqual(Say.clock(600), "10:00")
        // The count-up starts from a timestamp the server set, which can be a
        // moment ahead of this device's clock.
        XCTAssertEqual(Say.clock(-5), "0:00")
    }

    /// `PlainDate` parses in UTC, so the month has to be rendered in UTC too —
    /// otherwise the first of a month becomes the month before, but only for
    /// people west of Greenwich.
    func testMonthDoesNotSlipATimezone() {
        XCTAssertEqual(Say.month(from: "2026-03-01"), "March")
        XCTAssertEqual(Say.month(from: "2026-12-31"), "December")
        XCTAssertNil(Say.month(from: nil))
        XCTAssertNil(Say.month(from: "not a date"))
    }

    func testPlainDateRoundTrips() {
        let date = PlainDate.date(from: "2026-09-21")
        XCTAssertNotNil(date)
        XCTAssertEqual(PlainDate.string(from: date!), "2026-09-21")
        XCTAssertNil(PlainDate.date(from: "21/09/2026"))
    }
}
