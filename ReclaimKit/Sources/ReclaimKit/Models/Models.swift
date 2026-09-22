import Foundation

// Mirrors supabase/migrations. Explicit CodingKeys rather than a snake_case
// decoding strategy, so a column rename fails loudly at the one place that
// names it rather than silently decoding nil.

public enum SessionSource: String, Codable, Sendable {
    case app, tag, control, siri, shortcut, retroactive, nearby
}

public struct Profile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String?
    public var nudgeEnabled: Bool
    public var nudgeHour: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case nudgeEnabled = "nudge_enabled"
        case nudgeHour = "nudge_hour"
    }

    public init(id: UUID, displayName: String?, nudgeEnabled: Bool = true, nudgeHour: Int = 19) {
        self.id = id
        self.displayName = displayName
        self.nudgeEnabled = nudgeEnabled
        self.nudgeHour = nudgeHour
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
    /// Nil is "Somewhere", and counts exactly the same.
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
    public let retroactive: Bool
    public let source: SessionSource

    enum CodingKeys: String, CodingKey {
        case id, qualifying, retroactive, source
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
                retroactive: Bool = false, source: SessionSource = .app) {
        self.id = id; self.profileId = profileId; self.gatheringId = gatheringId
        self.startedAt = startedAt; self.endedAt = endedAt
        self.durationMinutes = durationMinutes; self.localDate = localDate
        self.qualifying = qualifying; self.autoClosed = autoClosed
        self.retroactive = retroactive; self.source = source
    }

    public var isLive: Bool { endedAt == nil }
}

/// One person in a gathering you are in. The ONLY thing the app ever learns
/// about someone else's session — no dates, no history, no counts.
public struct Member: Codable, Identifiable, Hashable, Sendable {
    public let profileId: UUID
    public let displayName: String?
    public let stillLive: Bool

    public var id: UUID { profileId }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case displayName = "display_name"
        case stillLive = "still_live"
    }

    public init(profileId: UUID, displayName: String?, stillLive: Bool) {
        self.profileId = profileId; self.displayName = displayName; self.stillLive = stillLive
    }
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

/// A state, not a rank. You are in a rhythm or between rhythms.
public struct Rhythm: Codable, Hashable, Sendable {
    public enum State: String, Codable, Sendable {
        case inRhythm = "in_rhythm"
        case between
    }

    public let state: State
    public let currentRunDays: Int
    public let longestRunDays: Int
    public let lastQualifyingDate: String?
    public let restDayAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case state
        case currentRunDays = "current_run_days"
        case longestRunDays = "longest_run_days"
        case lastQualifyingDate = "last_qualifying_date"
        case restDayAvailable = "rest_day_available"
    }

    public init(state: State, currentRunDays: Int, longestRunDays: Int,
                lastQualifyingDate: String?, restDayAvailable: Bool) {
        self.state = state; self.currentRunDays = currentRunDays
        self.longestRunDays = longestRunDays
        self.lastQualifyingDate = lastQualifyingDate
        self.restDayAvailable = restDayAvailable
    }

    public static let empty = Rhythm(state: .between, currentRunDays: 0,
                                     longestRunDays: 0, lastQualifyingDate: nil,
                                     restDayAvailable: true)
}
