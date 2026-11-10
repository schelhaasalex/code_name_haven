import Foundation

// Mirrors supabase/migrations. Explicit CodingKeys rather than a snake_case
// decoding strategy, so a column rename fails loudly at the one place that
// names it rather than silently decoding nil.

/// How an evening started. Only the box starts one now; the rest are kept
/// because evenings from before still say them.
public enum SessionSource: String, Codable, Sendable {
    /// `tag` is the box: evenings its radio starts are saved with it, though
    /// the slots' tags are gone. Renaming it needs a migration — the
    /// database checks the value — and old rows carry it. The rest are ways
    /// in that have gone too (rule 4), kept so old rows still decode.
    case app, tag, control, siri, shortcut, retroactive, nearby
}

/// Yours. Made silently on the first launch; nothing about it is set by hand,
/// so the app reads only which account it is. (The table still has the
/// name and nudge columns from before; nothing writes them.)
public struct Profile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID

    public init(id: UUID) {
        self.id = id
    }
}

public struct Place: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Nullable and stays that way. An unnamed place is valid.
    public var name: String?
    /// The word pair printed on the card. Display only — never a credential.
    public let handle: String
    public let createdBy: UUID?
    public let mergedInto: UUID?

    /// What a client may read of a place: every column except
    /// `join_secret_hash`, which is granted to no one (schema review, 3c). A
    /// bare `select()` asks for all columns, and Postgres then refuses the
    /// whole read — so it is always this list. `scripts/shape.sh` checks.
    public static let readableColumns = "id, name, handle, created_by, merged_into"

    enum CodingKeys: String, CodingKey {
        case id, name, handle
        case createdBy = "created_by"
        case mergedInto = "merged_into"
    }

    public init(id: UUID, name: String?, handle: String,
                createdBy: UUID? = nil, mergedInto: UUID? = nil) {
        self.id = id; self.name = name; self.handle = handle
        self.createdBy = createdBy; self.mergedInto = mergedInto
    }
}

public struct Gathering: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Nil only for evenings from before every evening was at a box.
    public let placeId: UUID?
    public let startedBy: UUID?
    public let startedAt: Date
    public let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case placeId = "place_id"
        case startedBy = "started_by"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }

    public init(id: UUID, placeId: UUID?, startedBy: UUID?,
                startedAt: Date, endedAt: Date? = nil) {
        self.id = id; self.placeId = placeId; self.startedBy = startedBy
        self.startedAt = startedAt; self.endedAt = endedAt
    }

    public var isLive: Bool { endedAt == nil }
}

public struct Session: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let profileId: UUID
    public let gatheringId: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let durationMinutes: Int?
    /// The calendar date in the user's own timezone when it STARTED. One that
    /// crosses midnight belongs to the earlier day.
    public let localDate: String
    public let qualifying: Bool
    public let autoClosed: Bool
    public let source: SessionSource

    enum CodingKeys: String, CodingKey {
        case id, qualifying, source
        case profileId = "profile_id"
        case gatheringId = "gathering_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case localDate = "local_date"
        case autoClosed = "auto_closed"
    }

    public init(id: UUID, profileId: UUID, gatheringId: UUID,
                startedAt: Date, endedAt: Date? = nil, durationMinutes: Int? = nil,
                localDate: String, qualifying: Bool = false, autoClosed: Bool = false,
                source: SessionSource = .app) {
        self.id = id; self.profileId = profileId; self.gatheringId = gatheringId
        self.startedAt = startedAt; self.endedAt = endedAt
        self.durationMinutes = durationMinutes; self.localDate = localDate
        self.qualifying = qualifying; self.autoClosed = autoClosed
        self.source = source
    }

    public var isLive: Bool { endedAt == nil }
}

public struct PlaceSummary: Codable, Hashable, Sendable {
    /// COUNT(DISTINCT local_date) — a five-person dinner is one evening.
    public let evenings: Int
    /// How long the room was gathered. Does not grow with household size.
    public let wallClockMinutes: Int
    /// Summed across people. This is the "hours reclaimed" supporting metric.
    public let personMinutes: Int
    public let stage: String
    public let since: String?
    public let liveNow: Bool

    enum CodingKeys: String, CodingKey {
        case evenings, stage, since
        case wallClockMinutes = "wall_clock_minutes"
        case personMinutes = "person_minutes"
        case liveNow = "live_now"
    }

    public init(evenings: Int, wallClockMinutes: Int, personMinutes: Int,
                stage: String, since: String?, liveNow: Bool) {
        self.evenings = evenings; self.wallClockMinutes = wallClockMinutes
        self.personMinutes = personMinutes; self.stage = stage
        self.since = since; self.liveNow = liveNow
    }
}
