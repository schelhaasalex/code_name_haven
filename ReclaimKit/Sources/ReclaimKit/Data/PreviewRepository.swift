import Foundation

/// Fixtures, so every screen builds in an Xcode preview with no network and no
/// account — and, in a debug build launched with `-sample-data`, so the whole
/// app runs against them. The names here are the ones on the canvas.
///
/// It remembers what happens to it, in memory only, the way the database
/// would: start an evening and it is live; end it and it is credited, capped
/// at three hours, and counts only past fifteen minutes. The rules it mirrors
/// live in `PreviewRepository+Evenings.swift`. Every launch starts fresh.
public final class PreviewRepository: Repository, @unchecked Sendable {

    public var profile: Profile
    public var places: [Place]
    public var live: Session?
    public var gatheringNow: Gathering?
    public var memberList: [Member]
    public var rhythm: Rhythm
    public var summaryValue: PlaceSummary
    /// Your ended evenings, newest first.
    public var history: [Session] = []
    var gatheringsById: [UUID: Gathering] = [:]
    /// Gatherings opened by this run, as opposed to the canvas fixtures. Only
    /// you are in those — nobody else's phone is here to join.
    var startedHere: Set<UUID> = []
    var signedIn = true

    public static let kitchenTable = UUID()
    public static let maya = UUID()
    public static let dad  = UUID()
    public static let me   = UUID()

    /// Screen 13's fixture. Credited AT THE CAP — three hours — rather than at
    /// the nine the phone actually sat there.
    public static let autoClosedSession = Session(
        id: UUID(), profileId: PreviewRepository.me, gatheringId: UUID(),
        startedAt: Date(timeIntervalSinceNow: -60 * 60 * 14),
        endedAt: Date(timeIntervalSinceNow: -60 * 60 * 11),
        durationMinutes: 180, localDate: PlainDate.string(from: .now),
        qualifying: true, autoClosed: true)

    public init(
        live: Session? = nil,
        members: [Member] = [
            Member(profileId: PreviewRepository.maya, displayName: "Maya", stillLive: true),
            Member(profileId: PreviewRepository.dad,  displayName: "Dad",  stillLive: true),
            Member(profileId: PreviewRepository.me,   displayName: "Alex", stillLive: true)
        ],
        places: [Place] = [
            Place(id: PreviewRepository.kitchenTable, name: "The Kitchen Table", handle: "amber-otter"),
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

    /// The household the `-sample-data` launch uses: the canvas fixtures, plus
    /// a few weeks of evenings so the dots and grids have something in them.
    /// Nothing live, and no nudge — the permission prompt is the real app's
    /// business, not a demo's.
    public static func sampleHousehold(now: Date = .now, calendar: Calendar = .current) -> PreviewRepository {
        let repo = PreviewRepository()
        repo.profile.nudgeEnabled = false
        repo.seedHistory(now: now, calendar: calendar)
        return repo
    }

    public func myProfile() async throws -> Profile? { signedIn ? profile : nil }
    public func upsertProfile(displayName: String?) async throws -> Profile {
        profile.displayName = displayName; return profile
    }
    public func updateProfile(nudgeEnabled: Bool, nudgeHour: Int) async throws {
        profile.nudgeEnabled = nudgeEnabled; profile.nudgeHour = nudgeHour
    }
    public func deleteAccount() async throws { signedIn = false }
    public func signOut() async throws { signedIn = false }

    public func myPlaces() async throws -> [Place] { places.filter { $0.mergedInto == nil } }
    public func place(_ id: UUID) async throws -> Place? { places.first { $0.id == id } }
    public func rename(place id: UUID, to name: String) async throws {
        if let i = places.firstIndex(where: { $0.id == id }) { places[i].name = name }
    }

    public func members(of gathering: UUID) async throws -> [Member] {
        guard startedHere.contains(gathering) else { return memberList }
        return [Member(profileId: profile.id, displayName: profile.displayName, stillLive: true)]
    }
    public func summary(of place: UUID) async throws -> PlaceSummary { summaryValue }
    public func myRhythm() async throws -> Rhythm { rhythm }
    public func resolvePlace(secret: String) async throws -> UUID? { places.first?.id }
}
