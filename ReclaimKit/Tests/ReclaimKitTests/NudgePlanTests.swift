import XCTest
@testable import ReclaimKit

/// The one nudge: when it goes out, and every time it doesn't.
final class NudgePlanTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return c
    }()

    /// Tuesday 22 September 2026 at the given time.
    private func at(_ day: Int = 22, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func hour(_ date: Date) -> Int { cal.component(.hour, from: date) }
    private func day(_ date: Date) -> Int { cal.component(.day, from: date) }

    func testWithoutEvidenceItUsesTheHourFromSettings() {
        let plan = NudgePlan.upcoming(starts: [at(21, 20)], lastEvening: at(21, 20),
                                      hour: 19, live: false, now: at(22, 9), calendar: cal)
        XCTAssertEqual(plan.first.map(hour), 19)
    }

    /// Three evenings around 20:15 is a usual time. Two isn't.
    func testAUsualTimeNeedsThreeEveningsCloseTogether() {
        let three = [at(18, 20, 10), at(19, 20, 30), at(20, 20, 0)]
        XCTAssertEqual(NudgePlan.usualTime(of: three, now: at(22, 9), calendar: cal).map { Int($0 / 3600) }, 20)
        XCTAssertNil(NudgePlan.usualTime(of: Array(three.prefix(2)), now: at(22, 9), calendar: cal))
    }

    func testScatteredEveningsHaveNoUsualTime() {
        let scattered = [at(18, 12), at(19, 18), at(20, 22)]
        XCTAssertNil(NudgePlan.usualTime(of: scattered, now: at(22, 9), calendar: cal))
    }

    /// Around midnight is still one usual time, not two ends of the clock.
    func testAUsualTimeCanStraddleMidnight() {
        let late = [at(18, 23, 40), at(19, 0, 10), at(20, 23, 55)]
        XCTAssertNotNil(NudgePlan.usualTime(of: late, now: at(22, 9), calendar: cal))
    }

    func testEveningsOlderThanThreeWeeksDontCount() {
        let old = [at(1, 20), at(2, 20), at(3, 20)]
        XCTAssertNil(NudgePlan.usualTime(of: old, now: at(28, 9), calendar: cal))
    }

    /// Already set it down today: nothing tonight, the next one tomorrow.
    func testNoNudgeOnADayThatHadAnEvening() {
        let plan = NudgePlan.upcoming(starts: [], lastEvening: at(22, 7), hour: 19,
                                      live: false, now: at(22, 9), calendar: cal)
        XCTAssertEqual(plan.first.map(day), 23)
    }

    func testNoNudgeDuringAnEvening() {
        let plan = NudgePlan.upcoming(starts: [], lastEvening: at(21, 20), hour: 19,
                                      live: true, now: at(22, 18), calendar: cal)
        XCTAssertFalse(plan.contains { day($0) == 22 })
    }

    /// Five days away: no catching up, no burst — just the spaced-out ones
    /// still ahead, fewer and fewer.
    func testFiveDaysAwayGetsFewerNotMore() {
        let plan = NudgePlan.upcoming(starts: [], lastEvening: at(17, 20), hour: 19,
                                      live: false, now: at(22, 20), calendar: cal)
        // 17 + 7, 10, 14, 21, 28 days.
        XCTAssertEqual(plan.map(day), [24, 27, 1, 8, 15])
    }

    /// Four weeks after the last evening, it stops.
    func testItFallsSilentAfterFourWeeks() {
        let plan = NudgePlan.upcoming(starts: [], lastEvening: at(1, 20), hour: 19,
                                      live: false, now: at(30, 20), calendar: cal)
        XCTAssertTrue(plan.isEmpty)
    }

    /// Any evening starts the count again from the next day.
    func testAnEveningResetsTheFade() {
        let plan = NudgePlan.upcoming(starts: [], lastEvening: at(22, 20), hour: 19,
                                      live: false, now: at(22, 21), calendar: cal)
        XCTAssertEqual(plan.prefix(3).map(day), [23, 24, 25])
    }
}
