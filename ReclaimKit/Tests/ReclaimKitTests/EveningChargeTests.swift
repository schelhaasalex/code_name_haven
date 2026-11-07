import XCTest
@testable import ReclaimKit

final class EveningChargeTests: XCTestCase {

    func testFourStepsThenItHolds() {
        XCTAssertEqual(EveningCharge.stage(minutes: 0), 0)
        XCTAssertEqual(EveningCharge.stage(minutes: 14.9), 0)
        XCTAssertEqual(EveningCharge.stage(minutes: 15), 1)
        XCTAssertEqual(EveningCharge.stage(minutes: 30), 2)
        XCTAssertEqual(EveningCharge.stage(minutes: 60), 3)
        XCTAssertEqual(EveningCharge.stage(minutes: 90), EveningCharge.full)
        XCTAssertEqual(EveningCharge.stage(minutes: 600), EveningCharge.full)
    }

    /// "Tonight counts." appears with the first segment, so the first segment
    /// has to be the moment an evening does count.
    func testTheFirstSegmentIsWhenTheEveningCounts() {
        XCTAssertEqual(EveningCharge.minutes.first, EveningLanding.qualifyingMinutes)
    }

    func testAStageForEachHeadline() {
        XCTAssertEqual(Copy.list("evening.stage").count, EveningCharge.full + 1)
    }

    /// A goodbye while the phone is being set down; after that, where the
    /// evening has got to — the same on the phone as on the lock screen.
    func testTheLineFollowsTheEvening() {
        XCTAssertEqual(EveningCharge.line(minutes: 0.5), t("session.line.solo"))
        XCTAssertEqual(EveningCharge.line(minutes: nil), t("session.line.solo"))
        XCTAssertEqual(EveningCharge.line(minutes: 8), "Settling in.")
        XCTAssertEqual(EveningCharge.line(minutes: 15), "Tonight counts.")
        XCTAssertEqual(EveningCharge.line(minutes: 600), "Recharged.")
        for minutes in [8.0, 15, 45, 75, 200] {
            XCTAssertEqual(EveningCharge.line(minutes: minutes),
                           EveningCharge.line(stage: EveningCharge.stage(minutes: minutes)))
        }
    }

    func testNoLightAloneOneEachTogether() {
        XCTAssertEqual(EveningCharge.lights(memberCount: 1), 0)
        XCTAssertEqual(EveningCharge.lights(memberCount: 2), 2)
        XCTAssertEqual(EveningCharge.lights(memberCount: 40), EveningCharge.mostLights)
        XCTAssertEqual(EveningCharge.lightAngles(2), [45, 225])
    }

    /// Activities started before the ring charged carry no stage. They must
    /// still decode, or the lock screen shows nothing.
    func testAStateWithoutAStageStillDecodes() throws {
        let old = #"{"startedAt": 783000000, "memberCount": 2, "placeName": "Low Vole"}"#
        let state = try JSONDecoder().decode(ReclaimActivityAttributes.ContentState.self, from: Data(old.utf8))
        XCTAssertEqual(state.stage, 0)
        XCTAssertEqual(state.memberCount, 2)
    }
}
