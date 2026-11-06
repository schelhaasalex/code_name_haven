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

    private func first(
        recent: [Session] = [],
        rhythm: Rhythm? = nil,
        evenings: Int = 0,
        oneTapOffered: Bool = false
    ) -> Interruption? {
        Interruption.first(
            recent: recent,
            rhythm: rhythm ?? self.rhythm(.inRhythm, longest: 3),
            evenings: evenings,
            oneTapOffered: oneTapOffered)
    }

    // MARK: - Precedence

    func testNothingToSayIsTheCommonCase() {
        let out = first(recent: [session()], evenings: 3)
        XCTAssertNil(out)
    }

    func testWhatWeDidOnTheirBehalfComesFirst() {
        let closed = session(autoClosed: true)
        let out = first(recent: [closed, session()],
                              rhythm: rhythm(.between, longest: 9),
                              evenings: 20)
        XCTAssertEqual(out, .autoClosed(closed))
    }

    func testTheMostRecentAutoCloseIsTheOneWeExplain() {
        let older = session(minutesAgo: 2000, autoClosed: true)
        let newer = session(minutesAgo: 300, autoClosed: true)
        let ascending = first(recent: [older, newer])
        let descending = first(recent: [newer, older])
        XCTAssertEqual(ascending, .autoClosed(newer))
        XCTAssertEqual(descending, .autoClosed(newer),
                       "the order the rows arrive in must not decide this")
    }

    func testARhythmEndingOutranksTheAsk() {
        let ended = rhythm(.between, longest: 9)
        let out = first(rhythm: ended, evenings: 20)
        XCTAssertEqual(out, .rhythmEnded(ended))
    }

    /// "That rhythm ended" after a single evening would be inventing a loss
    /// nobody felt — and the copy says days, plural.
    func testASingleEveningIsNotARhythmToHaveLost() {
        let oneDay = first(rhythm: rhythm(.between, longest: 1))
        let never = first(rhythm: rhythm(.between, longest: 0))
        let twoDays = first(rhythm: rhythm(.between, longest: 2))
        XCTAssertNil(oneDay)
        XCTAssertNil(never)
        XCTAssertNotNil(twoDays)
    }

    func testBeingInARhythmSaysNothingAtAll() {
        let out = first(rhythm: rhythm(.inRhythm, longest: 9))
        XCTAssertNil(out)
    }

    // MARK: - The one optional setup

    /// Screen 20 arrives after five EVENINGS. Counting sessions instead would
    /// fire it after one dinner with five people at the table.
    func testTheOneTapOfferWaitsForFiveEvenings() {
        let four = first(evenings: 4)
        let five = first(evenings: 5)
        let many = first(evenings: 31)
        XCTAssertNil(four)
        XCTAssertEqual(five, .makeItOneTap)
        XCTAssertEqual(many, .makeItOneTap)
    }

    /// Declining it is final. It is the only optional setup in the product and
    /// it never asks twice.
    func testDecliningTheOfferIsFinal() {
        let out = first(evenings: 31, oneTapOffered: true)
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
