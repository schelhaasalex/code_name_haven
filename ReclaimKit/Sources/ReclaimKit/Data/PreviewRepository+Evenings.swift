import Foundation

/// The session half of the fixtures: starting and ending, following
/// the same rules the database does, in memory.
///
/// Not a second implementation of the product's logic to be trusted — the
/// database is that. This is only enough for a demo to behave plausibly: one
/// live evening per person, credit capped at three hours, and an evening that
/// counts only past fifteen minutes.
extension PreviewRepository {

    /// Mirrors `app.qualifying_minutes()` and `app.auto_close_minutes()`.
    static let qualifyingMinutes = 15
    static let capMinutes = 180

    public func liveSession() async throws -> Session? { live }

    /// The canvas household's earlier evenings, before anything in `history`,
    /// plus whatever this run has added — counted as days, like the database.
    public func myEvenings() async throws -> EveningTotal {
        let days = Set(history.filter(\.qualifying).map(\.localDate))
        let first = Calendar.current.date(byAdding: .day, value: -112, to: .now) ?? .now
        return EveningTotal(count: earlierEvenings + days.count,
                            first: earlierEvenings > 0 ? Self.localDate(first) : days.min())
    }

    public func gathering(_ id: UUID) async throws -> Gathering? {
        gatheringsById[id] ?? gatheringNow
    }

    public func mySessions(since: Date) async throws -> [Session] {
        ([live].compactMap { $0 } + history).filter { $0.startedAt >= since }
    }

    public func delete(session id: UUID) async throws {
        if live?.id == id { live = nil }
        history.removeAll { $0.id == id }
    }

    /// One live evening per person: already in one, you stay in it.
    public func startOrJoin(place: UUID?, source: SessionSource) async throws -> UUID {
        if let live { return live.id }
        let now = Date()
        let g = Gathering(id: UUID(), placeId: place, startedBy: profile.id, startedAt: now)
        gatheringsById[g.id] = g
        gatheringNow = g
        startedHere.insert(g.id)
        let s = Session(id: UUID(), profileId: profile.id, gatheringId: g.id, startedAt: now,
                        localDate: Self.localDate(now), source: source)
        live = s
        return s.id
    }

    @discardableResult
    public func endSession(_ id: UUID?) async throws -> Int? {
        guard let s = live, id == nil || id == s.id else { return nil }
        let now = Date()
        let minutes = min(Self.capMinutes, Int(now.timeIntervalSince(s.startedAt) / 60))
        history.insert(ended(s, at: now, minutes: minutes), at: 0)
        live = nil
        gatheringNow = nil
        return minutes
    }

    /// The sample household's box is its kitchen table.
    public func dockPlace(secret: String, handle: String) async throws -> UUID? {
        places.first?.id
    }

    // MARK: - Seeding

    /// A believable few weeks at the kitchen table, some days missed. Never
    /// today — the demo is for starting one.
    func seedHistory(now: Date, calendar: Calendar) {
        let daysAgo = [1, 2, 4, 5, 7, 8, 9, 12, 14, 15, 19, 21, 22, 26]
        for (n, ago) in daysAgo.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -ago, to: now),
                  let start = calendar.date(bySettingHour: 19, minute: 20 + n, second: 0, of: day)
            else { continue }
            let minutes = 70 + (n * 17) % 90
            let g = Gathering(id: UUID(), placeId: Self.kitchenTable, startedBy: profile.id, startedAt: start,
                              endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)))
            gatheringsById[g.id] = g
            let s = Session(id: UUID(), profileId: profile.id, gatheringId: g.id, startedAt: start,
                            localDate: Self.localDate(start, calendar: calendar))
            history.append(ended(s, at: g.endedAt ?? start, minutes: minutes))
        }
    }

    private func ended(_ s: Session, at end: Date, minutes: Int) -> Session {
        Session(id: s.id, profileId: s.profileId, gatheringId: s.gatheringId,
                startedAt: s.startedAt, endedAt: end, durationMinutes: minutes,
                localDate: s.localDate, qualifying: minutes >= Self.qualifyingMinutes,
                autoClosed: false, retroactive: s.retroactive, source: s.source)
    }

    /// The date the evening STARTED, in the person's own zone — how the
    /// database computes `local_date`.
    static func localDate(_ date: Date, calendar: Calendar = .current) -> String {
        PlainDate.local(date, calendar: calendar)
    }
}
