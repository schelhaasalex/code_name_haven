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
    public var summaryValue: PlaceSummary
    /// Your ended evenings, newest first.
    public var history: [Session] = []
    /// Evenings older than `history`, so "your evenings" has a past in a
    /// preview. Zero for a household on day one.
    public var earlierEvenings = 24
    var gatheringsById: [UUID: Gathering] = [:]
    /// Gatherings opened by this run, as opposed to the canvas fixtures. Only
    /// you are in those — nobody else's phone is here to join.
    var startedHere: Set<UUID> = []
    var signedIn = true
    /// The sample household's account isn't kept with an Apple ID yet.
    var kept = false

    public static let kitchenTable = UUID()
    /// The house's second box, unnamed: it goes by its default.
    public static let bedroom = UUID()
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
            Place(id: PreviewRepository.kitchenTable, name: "The Kitchen Table", handle: "amber-otter",
                  createdBy: PreviewRepository.me)
        ]
    ) {
        self.profile = Profile(id: PreviewRepository.me, displayName: "Alex")
        self.places = places
        self.live = live
        self.memberList = members
        self.earlierEvenings = places.isEmpty ? 0 : 24
        self.summaryValue = PlaceSummary(evenings: 31, wallClockMinutes: 4080,
                                         personMinutes: 12240, stage: "settled in",
                                         since: "2026-03-04", liveNow: true)
    }

    /// The household the `-sample-data` launch uses: the canvas fixtures, plus
    /// a few weeks of evenings so the dots have something in them. Nothing
    /// live: the demo is for putting a phone in the box.
    public static func sampleHousehold(now: Date = .now, calendar: Calendar = .current) -> PreviewRepository {
        let repo = PreviewRepository()
        repo.places.append(Place(id: bedroom, name: nil, handle: "quiet-wren", createdBy: me))
        repo.seedHistory(now: now, calendar: calendar)
        return repo
    }

    public func signInAnonymously() async throws { signedIn = true }
    public func myProfile() async throws -> Profile? { signedIn ? profile : nil }
    public func deleteAccount() async throws { signedIn = false }
    public func isKept() async -> Bool { kept }
    public func note(_ note: Note, place: UUID?, detail: [String: String]) async throws {}
    public func keep(appleIdToken: String, nonce: String) async throws { kept = true }
    public func signIn(appleIdToken: String, nonce: String) async throws { signedIn = true; kept = true }

    public func myPlaces() async throws -> [Place] { places.filter { $0.mergedInto == nil } }
    public func rename(place id: UUID, to name: String) async throws {
        if let i = places.firstIndex(where: { $0.id == id }) { places[i].name = name }
    }

    public func members(of gathering: UUID) async throws -> [Member] {
        guard startedHere.contains(gathering) else { return memberList }
        return [Member(profileId: profile.id, displayName: profile.displayName, stillLive: true)]
    }
    public func summary(of place: UUID) async throws -> PlaceSummary {
        guard place == Self.bedroom else { return summaryValue }
        return PlaceSummary(evenings: 6, wallClockMinutes: 410, personMinutes: 690,
                            stage: "on its way", since: "2026-10-30", liveNow: false)
    }

    /// The sample household has no server and no lock screen to push to.
    public func saveActivityToken(_ token: String, environment: String) async throws {}
    public func startActivityRemotely(body: Data) async throws {}
    public func saveLiveActivity(token: String, gatheringId: UUID, environment: String, state: String) async throws {}
}
