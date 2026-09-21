import XCTest
@testable import ReclaimKit

/// The sample-data mode is only as good as the fixtures' memory: if starting
/// an evening doesn't make one live, the demo silently does nothing — which is
/// exactly what it did before these existed.
final class PreviewRepositoryTests: XCTestCase {

    func testStartingAnEveningMakesItLive() async throws {
        let repo = PreviewRepository.sampleHousehold()
        let id = try await repo.startOrJoin(place: PreviewRepository.kitchenTable, source: .app)
        let live = try await repo.liveSession()
        XCTAssertEqual(live?.id, id)
        let gathering = try await repo.gathering(try XCTUnwrap(live).gatheringId)
        XCTAssertEqual(gathering?.placeId, PreviewRepository.kitchenTable)
    }

    /// One live evening per person, as in the database.
    func testStartingAgainJoinsTheSameEvening() async throws {
        let repo = PreviewRepository.sampleHousehold()
        let first = try await repo.startOrJoin(place: nil, source: .app)
        let second = try await repo.startOrJoin(place: PreviewRepository.kitchenTable, source: .tag)
        XCTAssertEqual(first, second)
    }

    /// Nobody else's phone is in the demo, so nobody else is in an evening
    /// started in it.
    func testAnEveningStartedHereIsJustYou() async throws {
        let repo = PreviewRepository.sampleHousehold()
        _ = try await repo.startOrJoin(place: nil, source: .app)
        let live = try await repo.liveSession()
        let members = try await repo.members(of: try XCTUnwrap(live).gatheringId)
        XCTAssertEqual(members.map(\.displayName), ["Alex"])
    }

    /// Ended at once, it's credited but doesn't count — under fifteen minutes.
    func testEndingCreditsItAndAShortOneDoesNotCount() async throws {
        let repo = PreviewRepository.sampleHousehold()
        _ = try await repo.startOrJoin(place: nil, source: .app)
        let minutes = try await repo.endSession(nil)
        XCTAssertEqual(minutes, 0)
        let live = try await repo.liveSession()
        XCTAssertNil(live)
        let latest = try XCTUnwrap(repo.history.first)
        XCTAssertNotNil(latest.endedAt)
        XCTAssertFalse(latest.qualifying)
    }

    func testTheSampleHouseholdHasHistoryButNothingToday() async throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let repo = PreviewRepository.sampleHousehold(now: now)
        let sessions = try await repo.mySessions(since: now.addingTimeInterval(-35 * 86_400))
        XCTAssertGreaterThan(sessions.filter(\.qualifying).count, 5)
        XCTAssertFalse(sessions.contains { $0.localDate == PreviewRepository.localDate(now) })
        XCTAssertFalse(repo.profile.nudgeEnabled, "a demo shouldn't open with a permission prompt")
    }

    /// Like `name_somewhere`: your unnamed evenings move onto the new place.
    func testNamingSomewhereAdoptsThePlacelessEvenings() async throws {
        let repo = PreviewRepository.sampleHousehold()
        let before = try await repo.gatherings(ids: repo.history.map(\.gatheringId))
        XCTAssertTrue(before.contains { $0.placeId == nil })

        let id = try await repo.nameSomewhere(handle: "still-lantern", secret: "s", name: "The Porch")
        let after = try await repo.gatherings(ids: repo.history.map(\.gatheringId))
        XCTAssertFalse(after.contains { $0.placeId == nil })
        XCTAssertTrue(after.contains { $0.placeId == id })
    }
}
