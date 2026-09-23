import XCTest
@testable import ReclaimKit

/// Screen 18 offers; a person confirms. A false positive costs a tap. A false
/// negative — telling someone they weren't there when they obviously were — is
/// the worst failure this product can have, so most of these are about what is
/// NOT offered.
final class StationaryRunsTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_790_000_000)
    private func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }

    private func sample(_ minutes: Double, stationary: Bool, confident: Bool = true)
    -> StationaryRuns.Sample {
        .init(start: at(minutes), stationary: stationary, confident: confident)
    }

    // MARK: - Runs

    func testAStretchOfStillnessBecomesOneRun() {
        let runs = StationaryRuns.runs(
            from: [sample(0, stationary: false),
                   sample(10, stationary: true),
                   sample(70, stationary: false),
                   sample(80, stationary: false)],
            until: at(120))
        XCTAssertEqual(runs, [.init(start: at(10), end: at(70))])
        XCTAssertEqual(runs.first?.duration, 60 * 60)
    }

    /// The sensor shrugging is not the phone moving. Splitting a real evening
    /// in two over a low-confidence sample is how a two-hour dinner becomes two
    /// fifty-minute stretches that both fall under the minimum.
    func testLowConfidenceSamplesAreIgnoredNotTreatedAsMovement() {
        let runs = StationaryRuns.runs(
            from: [sample(0, stationary: true),
                   sample(30, stationary: false, confident: false),
                   sample(90, stationary: false)],
            until: at(120))
        XCTAssertEqual(runs, [.init(start: at(0), end: at(90))])
    }

    /// The phone is still on the table right now. The run is open, and closing
    /// it at the query's end is what makes tonight offerable.
    func testAnOpenRunClosesAtTheEndOfTheWindow() {
        let runs = StationaryRuns.runs(from: [sample(0, stationary: true)], until: at(45))
        XCTAssertEqual(runs, [.init(start: at(0), end: at(45))])
    }

    func testNothingToSayWhenNothingSatStill() {
        XCTAssertTrue(StationaryRuns.runs(from: [], until: at(60)).isEmpty)
        XCTAssertTrue(StationaryRuns.runs(
            from: [sample(0, stationary: false), sample(30, stationary: false)],
            until: at(60)).isEmpty)
        // Confident about nothing is still nothing.
        XCTAssertTrue(StationaryRuns.runs(
            from: [sample(0, stationary: true, confident: false)], until: at(60)).isEmpty)
    }

    func testARunThatWouldEndBeforeItBeganIsDropped() {
        XCTAssertTrue(StationaryRuns.runs(from: [sample(60, stationary: true)],
                                          until: at(30)).isEmpty)
    }

    // MARK: - The candidate

    /// Every candidate test needs a history now: a run is only offered when it
    /// ends the way one of your own evenings ended. `mine` is somebody who
    /// finishes at both of the times these runs finish.
    private var mine: [Date] { [at(20), at(200), at(340), at(30), at(15), at(120)] }

    func testTheLongestRunPastTheMinimumWins() {
        let short = StationaryRuns.Run(start: at(0), end: at(20))
        let long = StationaryRuns.Run(start: at(60), end: at(200))
        XCTAssertEqual(StationaryRuns.candidate(runs: [short, long], existing: [], evenings: mine),
                       long)
    }

    func testANearMissIsNotOffered() {
        let almost = StationaryRuns.Run(start: at(0), end: at(14))
        XCTAssertNil(StationaryRuns.candidate(runs: [almost], existing: [], evenings: mine))
        // Exactly the minimum qualifies.
        let exactly = StationaryRuns.Run(start: at(0), end: at(15))
        XCTAssertEqual(StationaryRuns.candidate(runs: [exactly], existing: [], evenings: mine),
                       exactly)
    }

    /// Offering an evening that was already counted would read as the app
    /// having forgotten, and accepting it would double-count the night.
    func testSomethingAlreadyCountedIsNotOfferedAgain() {
        let run = StationaryRuns.Run(start: at(0), end: at(120))
        let overlapping = [(start: at(60), end: at(200))]
        XCTAssertNil(StationaryRuns.candidate(runs: [run], existing: overlapping, evenings: mine))

        let adjacent = [(start: at(120), end: at(200))]
        XCTAssertEqual(StationaryRuns.candidate(runs: [run], existing: adjacent, evenings: mine), run,
                       "a session that starts as this run ends does not overlap it")
    }

    func testAnOverlapDoesNotHideTheOtherRuns() {
        let counted = StationaryRuns.Run(start: at(0), end: at(200))
        let free = StationaryRuns.Run(start: at(300), end: at(340))
        XCTAssertEqual(
            StationaryRuns.candidate(runs: [counted, free],
                                     existing: [(start: at(0), end: at(200))],
                                     evenings: mine),
            free)
    }

    func testTheMinimumIsAParameterNotAnAssumption() {
        let run = StationaryRuns.Run(start: at(0), end: at(30))
        XCTAssertNil(StationaryRuns.candidate(runs: [run], existing: [], evenings: mine,
                                              minimum: 60 * 60))
        XCTAssertEqual(StationaryRuns.candidate(runs: [run], existing: [], evenings: mine,
                                                minimum: 60), run)
    }

    // MARK: - Telling a night from an evening

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func clock(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day,
                                           hour: hour, minute: minute))!
    }

    /// The bug, as it happened: opened the app on a Tuesday morning and was
    /// offered nine hours and four minutes of sleep as an evening.
    func testTheNightIsNotOfferedAsAnEvening() {
        let night = StationaryRuns.Run(start: clock(22, 21, 42), end: clock(23, 6, 46))
        let usual = [clock(20, 22, 10), clock(21, 21, 55), clock(19, 22, 30)]
        XCTAssertNil(StationaryRuns.candidate(runs: [night], existing: [], evenings: usual,
                                              calendar: calendar))
    }

    /// The evening it is actually for: you set the phone down and forgot to
    /// say so, and it ended when your evenings end.
    func testAnEveningThatEndsLikeYoursIsOffered() {
        let forgotten = StationaryRuns.Run(start: clock(22, 19, 30), end: clock(22, 21, 15))
        let usual = [clock(20, 21, 30), clock(21, 20, 50)]
        XCTAssertEqual(StationaryRuns.candidate(runs: [forgotten], existing: [], evenings: usual,
                                                calendar: calendar),
                       forgotten)
    }

    /// Day one. The app has never seen an evening of yours, so it has no idea
    /// what one of yours looks like, and says nothing.
    func testNothingIsOfferedBeforeThereIsAnythingToCompareWith() {
        let plausible = StationaryRuns.Run(start: clock(22, 19, 30), end: clock(22, 21, 15))
        XCTAssertNil(StationaryRuns.candidate(runs: [plausible], existing: [], evenings: [],
                                              calendar: calendar))
    }

    /// Longer than the app would ever credit. A live evening that runs this
    /// long is closed at three hours; one the app INVENTS at this length is
    /// not an evening at all.
    func testNothingLongerThanTheAppWouldCreditIsOffered() {
        let allDay = StationaryRuns.Run(start: clock(22, 17, 30), end: clock(22, 21, 15))
        let usual = [clock(20, 21, 20)]
        XCTAssertNil(StationaryRuns.candidate(runs: [allDay], existing: [], evenings: usual,
                                              calendar: calendar))
        XCTAssertEqual(allDay.duration, 3.75 * 3600)
    }

    /// Clock time is a circle. Somebody who finishes at ten past midnight
    /// should be recognised at five to twelve.
    func testAnEveningEitherSideOfMidnightIsTheSameTimeOfDay() {
        let late = StationaryRuns.Run(start: clock(22, 22, 30), end: clock(22, 23, 55))
        let usual = [clock(21, 0, 10)]
        XCTAssertEqual(StationaryRuns.candidate(runs: [late], existing: [], evenings: usual,
                                                calendar: calendar),
                       late)
    }

    /// A stretch at a time of day you have never finished an evening: the
    /// phone on a desk all morning, ending when the meeting did.
    func testStillnessAtAnUnfamiliarHourIsNotOffered() {
        let desk = StationaryRuns.Run(start: clock(22, 9, 30), end: clock(22, 11, 0))
        let usual = [clock(20, 21, 30), clock(21, 22, 0)]
        XCTAssertNil(StationaryRuns.candidate(runs: [desk], existing: [], evenings: usual,
                                              calendar: calendar))
    }
}
