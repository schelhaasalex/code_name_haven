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

    func testTheLongestRunPastTheMinimumWins() {
        let short = StationaryRuns.Run(start: at(0), end: at(20))
        let long = StationaryRuns.Run(start: at(60), end: at(200))
        XCTAssertEqual(StationaryRuns.candidate(runs: [short, long], existing: []), long)
    }

    func testANearMissIsNotOffered() {
        let almost = StationaryRuns.Run(start: at(0), end: at(14))
        XCTAssertNil(StationaryRuns.candidate(runs: [almost], existing: []))
        // Exactly the minimum qualifies.
        let exactly = StationaryRuns.Run(start: at(0), end: at(15))
        XCTAssertEqual(StationaryRuns.candidate(runs: [exactly], existing: []), exactly)
    }

    /// Offering an evening that was already counted would read as the app
    /// having forgotten, and accepting it would double-count the night.
    func testSomethingAlreadyCountedIsNotOfferedAgain() {
        let run = StationaryRuns.Run(start: at(0), end: at(120))
        let overlapping = [(start: at(60), end: at(200))]
        XCTAssertNil(StationaryRuns.candidate(runs: [run], existing: overlapping))

        let adjacent = [(start: at(120), end: at(200))]
        XCTAssertEqual(StationaryRuns.candidate(runs: [run], existing: adjacent), run,
                       "a session that starts as this run ends does not overlap it")
    }

    func testAnOverlapDoesNotHideTheOtherRuns() {
        let counted = StationaryRuns.Run(start: at(0), end: at(200))
        let free = StationaryRuns.Run(start: at(300), end: at(340))
        XCTAssertEqual(
            StationaryRuns.candidate(runs: [counted, free],
                                     existing: [(start: at(0), end: at(200))]),
            free)
    }

    func testTheMinimumIsAParameterNotAnAssumption() {
        let run = StationaryRuns.Run(start: at(0), end: at(30))
        XCTAssertNil(StationaryRuns.candidate(runs: [run], existing: [], minimum: 60 * 60))
        XCTAssertEqual(StationaryRuns.candidate(runs: [run], existing: [], minimum: 60), run)
    }
}
