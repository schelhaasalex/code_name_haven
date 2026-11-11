import Foundation

/// When the day's one nudge goes, for someone who said yes to it. Learned
/// from the box, never asked for: a little before their phone usually goes in.
///
/// One a day at most, never on a day that already counts, and never before
/// seven in the morning or after a quarter to ten at night. Planned a week
/// ahead and refilled only when the app runs, so someone who stops opening it
/// gets a week of them and then nothing. Nothing here tries to win anyone
/// back.
public enum NudgeSchedule {
    /// Days planned ahead.
    public static let ahead = 7
    /// How long before their usual time, in minutes.
    public static let lead = 15
    /// How many of the most recent days that counted the usual time is drawn
    /// from.
    public static let recent = 14
    /// The waking hours' edges, in minutes past midnight.
    public static let earliest = 7 * 60
    public static let latest = 21 * 60 + 45
    /// Before five in the morning it is still the night before, as
    /// `Say.partOfDay` has it: a phone in at half past midnight is late,
    /// not early.
    static let dayTurns = 5 * 60

    /// Minutes past midnight: the median time a phone went in over the most
    /// recent days that counted — the first time each day — less `lead`, to
    /// the nearest five, and kept to the waking hours. Nil with nothing to go
    /// on.
    public static func minute(of starts: [Date], calendar: Calendar = .current) -> Int? {
        var firstOfDay: [String: Date] = [:]
        for start in starts {
            let day = PlainDate.local(start, calendar: calendar)
            if let known = firstOfDay[day], known <= start { continue }
            firstOfDay[day] = start
        }
        let minutes = firstOfDay.keys.sorted().suffix(recent).compactMap { firstOfDay[$0] }.map { start in
            let m = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
            return m < dayTurns ? m + 24 * 60 : m
        }.sorted()
        guard !minutes.isEmpty else { return nil }
        let median = minutes[(minutes.count - 1) / 2]
        let rounded = Int((Double(median - lead) / 5).rounded()) * 5
        return min(max(rounded, earliest), latest)
    }

    /// The moments to plan: `ahead` days from today at `minute`, leaving out
    /// today if it already counts or the moment has passed.
    public static func dates(at minute: Int, from now: Date, todayCounts: Bool,
                             calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<ahead).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let at = moment(minute, on: day, calendar: calendar) else { return nil }
            if offset == 0, todayCounts || at <= now { return nil }
            return at
        }
    }

    /// `minute` past midnight on `day`, by the clock on the wall — so it
    /// stays at 6:40 across a change of the clocks.
    public static func moment(_ minute: Int, on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: minute / 60 % 24, minute: minute % 60, second: 0, of: day)
    }

    /// The line for `date`'s nudge, taking each in turn day by day, so two
    /// days running never read alike when there are two to choose from.
    public static func line(_ lines: [String], on date: Date, calendar: Calendar = .current) -> String? {
        guard !lines.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return lines[day % lines.count]
    }
}
