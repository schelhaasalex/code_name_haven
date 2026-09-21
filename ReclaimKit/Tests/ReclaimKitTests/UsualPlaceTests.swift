import XCTest
@testable import ReclaimKit

/// Home's "Start it at…" — a claim about your history, so it has to be true.
final class UsualPlaceTests: XCTestCase {

    private let kitchen = Place(id: UUID(), name: "The Kitchen Table", handle: "amber-otter")
    private let office  = Place(id: UUID(), name: "The Office", handle: "slow-marten")
    private var gatherings: [UUID: Gathering] = [:]

    /// One of your evenings: at a place, or Somewhere when `place` is nil.
    private func evening(_ date: String, at place: Place?, qualifying: Bool = true) -> Session {
        let g = Gathering(id: UUID(), placeId: place?.id, startedBy: nil, startedAt: .now)
        gatherings[g.id] = g
        return Session(id: UUID(), profileId: UUID(), gatheringId: g.id, startedAt: .now,
                       localDate: date, qualifying: qualifying)
    }

    /// Listed second, so the old `places.first` would have picked the wrong one.
    func testItIsWhereMostEveningsWereNotTheFirstPlace() {
        let sessions = [evening("2026-09-18", at: office),
                        evening("2026-09-19", at: kitchen),
                        evening("2026-09-20", at: kitchen)]
        XCTAssertEqual(UsualPlace.among(sessions, gatherings: gatherings, places: [office, kitchen]), kitchen)
    }

    func testNoHistoryMeansNoSuggestion() {
        XCTAssertNil(UsualPlace.among([], gatherings: [:], places: [kitchen, office]))
    }

    /// Somewhere counts the same, but it isn't a place you can start at.
    func testSomewhereAndShortSessionsDontCount() {
        let sessions = [evening("2026-09-18", at: nil),
                        evening("2026-09-19", at: nil),
                        evening("2026-09-20", at: office, qualifying: false)]
        XCTAssertNil(UsualPlace.among(sessions, gatherings: gatherings, places: [kitchen, office]))
    }

    /// Two sessions on one evening are one evening there.
    func testEveningsNotSessions() {
        let sessions = [evening("2026-09-19", at: office),
                        evening("2026-09-19", at: office),
                        evening("2026-09-18", at: kitchen),
                        evening("2026-09-20", at: kitchen)]
        XCTAssertEqual(UsualPlace.among(sessions, gatherings: gatherings, places: [office, kitchen]), kitchen)
    }

    func testATieGoesToTheMostRecent() {
        let sessions = [evening("2026-09-18", at: kitchen),
                        evening("2026-09-20", at: office)]
        XCTAssertEqual(UsualPlace.among(sessions, gatherings: gatherings, places: [kitchen, office]), office)
    }

    func testAMergedAwayPlaceIsNeverSuggested() {
        let merged = Place(id: office.id, name: office.name, handle: office.handle, mergedInto: kitchen.id)
        let sessions = [evening("2026-09-20", at: office)]
        XCTAssertNil(UsualPlace.among(sessions, gatherings: gatherings, places: [merged]))
    }
}
