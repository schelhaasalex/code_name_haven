import XCTest
@testable import ReclaimKit

/// At most one of these per launch, and which one is a judgement about what is
/// owed to the person — not an accident of the order the checks were written.
final class InterruptionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func session(
        minutesAgo: Double = 60,
        qualifying: Bool = true,
        autoClosed: Bool = false,
        localDate: String = "2026-09-21"
    ) -> Session {
        let started = now.addingTimeInterval(-minutesAgo * 60)
        return Session(id: UUID(), profileId: UUID(), gatheringId: UUID(),
                       startedAt: started, endedAt: started.addingTimeInterval(3600),
                       durationMinutes: 60, localDate: localDate,
                       qualifying: qualifying, autoClosed: autoClosed)
    }

    private func rhythm(_ state: Rhythm.State, longest: Int = 0) -> Rhythm {
        Rhythm(state: state, currentRunDays: state == .inRhythm ? longest : 0,
               longestRunDays: longest, lastQualifyingDate: "2026-09-21",
               restDayAvailable: true)
    }

    private func satStill() -> StationaryRuns.Run {
        .init(start: now.addingTimeInterval(-7200), end: now)
    }

    private func first(
        recent: [Session] = [],
        rhythm: Rhythm? = nil,
        evenings: Int = 0,
        oneTapOffered: Bool = false,
        stationary: StationaryRuns.Run? = nil
    ) async -> Interruption? {
        await Interruption.first(
            recent: recent,
            rhythm: rhythm ?? self.rhythm(.inRhythm, longest: 3),
            evenings: evenings,
            oneTapOffered: oneTapOffered,
            stationary: { stationary })
    }

    // MARK: - Precedence

    func testNothingToSayIsTheCommonCase() async {
        let out = await first(recent: [session()], evenings: 3)
        XCTAssertNil(out)
    }

    func testWhatWeDidOnTheirBehalfComesFirst() async {
        let closed = session(autoClosed: true)
        let out = await first(recent: [closed, session()],
                              rhythm: rhythm(.between, longest: 9),
                              evenings: 20, stationary: satStill())
        XCTAssertEqual(out, .autoClosed(closed))
    }

    func testTheMostRecentAutoCloseIsTheOneWeExplain() async {
        let older = session(minutesAgo: 2000, autoClosed: true)
        let newer = session(minutesAgo: 300, autoClosed: true)
        let ascending = await first(recent: [older, newer])
        let descending = await first(recent: [newer, older])
        XCTAssertEqual(ascending, .autoClosed(newer))
        XCTAssertEqual(descending, .autoClosed(newer),
                       "the order the rows arrive in must not decide this")
    }

    func testARhythmEndingOutranksAGuess() async {
        let ended = rhythm(.between, longest: 9)
        let out = await first(rhythm: ended, evenings: 20, stationary: satStill())
        XCTAssertEqual(out, .rhythmEnded(ended))
    }

    /// "That rhythm ended" after a single evening would be inventing a loss
    /// nobody felt — and the copy says days, plural.
    func testASingleEveningIsNotARhythmToHaveLost() async {
        let oneDay = await first(rhythm: rhythm(.between, longest: 1))
        let never = await first(rhythm: rhythm(.between, longest: 0))
        let twoDays = await first(rhythm: rhythm(.between, longest: 2))
        XCTAssertNil(oneDay)
        XCTAssertNil(never)
        XCTAssertNotNil(twoDays)
    }

    func testBeingInARhythmSaysNothingAtAll() async {
        let out = await first(rhythm: rhythm(.inRhythm, longest: 9))
        XCTAssertNil(out)
    }

    func testTheGuessOutranksTheAsk() async {
        let sat = satStill()
        let out = await first(evenings: 20, stationary: sat)
        XCTAssertEqual(out, .countThat(from: sat.start, to: sat.end))
    }

    // MARK: - The sensor

    /// Asking CoreMotion is what prompts for Motion & Fitness. A person whose
    /// rhythm just ended should not be asked for a permission to answer a
    /// question we aren't going to put to them this launch.
    func testTheSensorIsNotAskedWhenSomethingLouderIsWaiting() async {
        var asked = false
        let out = await Interruption.first(
            recent: [session(autoClosed: true)],
            rhythm: rhythm(.between, longest: 9),
            evenings: 20,
            oneTapOffered: false,
            stationary: { asked = true; return self.satStill() })
        XCTAssertFalse(asked)
        XCTAssertNotNil(out)
    }

    func testTheSensorIsAskedWhenNothingElseIsWaiting() async {
        var asked = false
        _ = await Interruption.first(
            recent: [], rhythm: rhythm(.inRhythm, longest: 3), evenings: 20,
            oneTapOffered: false, stationary: { asked = true; return nil })
        XCTAssertTrue(asked)
    }

    // MARK: - The one optional setup

    /// Screen 20 arrives after five EVENINGS. Counting sessions instead would
    /// fire it after one dinner with five people at the table.
    func testTheOneTapOfferWaitsForFiveEvenings() async {
        let four = await first(evenings: 4)
        let five = await first(evenings: 5)
        let many = await first(evenings: 31)
        XCTAssertNil(four)
        XCTAssertEqual(five, .makeItOneTap)
        XCTAssertEqual(many, .makeItOneTap)
    }

    /// Declining it is final. It is the only optional setup in the product and
    /// it never asks twice.
    func testDecliningTheOfferIsFinal() async {
        let out = await first(evenings: 31, oneTapOffered: true)
        XCTAssertNil(out)
    }

    // MARK: - Identity

    /// The `id` drives `.sheet(item:)`. Two different auto-closed sessions must
    /// not share one, or the second never presents.
    func testIdsAreDistinctPerOccasion() {
        let a = Interruption.autoClosed(session(autoClosed: true))
        let b = Interruption.autoClosed(session(autoClosed: true))
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(Interruption.makeItOneTap.id, "one-tap")
        XCTAssertEqual(Interruption.rhythmEnded(rhythm(.between, longest: 2)).id,
                       "rhythm-ended")
    }
}
