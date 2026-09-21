import Foundation

/// Fixtures, so every screen builds in an Xcode preview with no network and no
/// account. The names here are the ones on the canvas.
public final class PreviewRepository: Repository, @unchecked Sendable {

    public var profile: Profile
    public var places: [Place]
    public var live: Session?
    public var gatheringNow: Gathering?
    public var memberList: [Member]
    public var rhythm: Rhythm
    public var summaryValue: PlaceSummary

    public static let maya = UUID()
    public static let dad  = UUID()
    public static let me   = UUID()

    public init(
        live: Session? = nil,
        members: [Member] = [
            Member(profileId: PreviewRepository.maya, displayName: "Maya", stillLive: true),
            Member(profileId: PreviewRepository.dad,  displayName: "Dad",  stillLive: true),
            Member(profileId: PreviewRepository.me,   displayName: "Alex", stillLive: true)
        ],
        places: [Place] = [
            Place(id: UUID(), name: "The Kitchen Table", handle: "amber-otter"),
            Place(id: UUID(), name: "Sam's Kitchen",     handle: "quiet-heron"),
            Place(id: UUID(), name: "The Office",        handle: "slow-marten")
        ],
        rhythm: Rhythm = Rhythm(state: .inRhythm, currentRunDays: 9, longestRunDays: 19,
                                lastQualifyingDate: PlainDate.string(from: .now),
                                restDayAvailable: true)
    ) {
        self.profile = Profile(id: PreviewRepository.me, displayName: "Alex")
        self.places = places
        self.live = live
        self.memberList = members
        self.rhythm = rhythm
        self.summaryValue = PlaceSummary(evenings: 31, wallClockMinutes: 4080,
                                         personMinutes: 12240, stage: "a reclaim house",
                                         since: "2026-03-04", liveNow: true)
    }

    public func myProfile() async throws -> Profile? { profile }
    public func upsertProfile(displayName: String?) async throws -> Profile {
        profile.displayName = displayName; return profile
    }
    public func updateProfile(nudgeEnabled: Bool, nudgeHour: Int) async throws {
        profile.nudgeEnabled = nudgeEnabled; profile.nudgeHour = nudgeHour
    }
    public func deleteAccount() async throws {}

    public func myPlaces() async throws -> [Place] { places }
    public func place(_ id: UUID) async throws -> Place? { places.first { $0.id == id } }
    public func rename(place id: UUID, to name: String) async throws {
        if let i = places.firstIndex(where: { $0.id == id }) { places[i].name = name }
    }

    public func liveSession() async throws -> Session? { live }
    public func gathering(_ id: UUID) async throws -> Gathering? { gatheringNow }
    public func mySessions(since: Date) async throws -> [Session] { [] }
    public func delete(session id: UUID) async throws { live = nil }

    public func startOrJoin(place: UUID?, source: SessionSource) async throws -> UUID { UUID() }
    @discardableResult public func endSession(_ id: UUID?) async throws -> Int? { 134 }
    public func recordRetroactive(from: Date, to: Date) async throws -> UUID { UUID() }
    public func members(of gathering: UUID) async throws -> [Member] { memberList }
    public func summary(of place: UUID) async throws -> PlaceSummary { summaryValue }
    public func myRhythm() async throws -> Rhythm { rhythm }
    public func resolvePlace(secret: String) async throws -> UUID? { places.first?.id }
    public func createPlace(handle: String, secret: String, name: String?) async throws -> UUID { UUID() }
    public func nameSomewhere(handle: String, secret: String, name: String) async throws -> UUID { UUID() }
    public func mergePlaces(from: UUID, into: UUID) async throws {}
}
