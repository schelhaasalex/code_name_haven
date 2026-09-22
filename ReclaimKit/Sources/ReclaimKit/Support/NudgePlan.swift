import Foundation

/// When the one evening nudge goes out — and, as much, when it doesn't.
///
/// It used to be a notification repeating every day at 7pm, forever: on days
/// you'd already set it down, during an evening, and on the fortieth day of
/// not opening the app. This is the kind version, as plain arithmetic so each
/// promise is a test:
///
/// - **At your usual time only with evidence.** Three evenings in the last
///   three weeks that started within 45 minutes of each other; otherwise the
///   hour in Settings. "Usual" is only said when it's true.
/// - **Never on a day that already had an evening, or during one.**
/// - **Fading, never escalating.** Nudges are counted from your last evening
///   and spread out — the next day, then every other, then twice a week, then
///   weekly — and stop after four weeks. Any evening starts the count again.
///   Nothing ever mentions the gap.
///
/// Scheduled ahead, because someone drifting away is exactly who never opens
/// the app for it to decide anything.
public enum NudgePlan {

    /// Days after the last evening on which a nudge may go out. After the last
    /// one, silence until the next evening.
    public static let fade = [1, 2, 3, 5, 7, 10, 14, 21, 28]

    /// The next nudges, soonest first.
    ///
    /// - Parameters:
    ///   - starts: when your recent evenings started (qualifying ones).
    ///   - lastEvening: the start of your most recent evening, if any.
    ///   - hour: the hour from Settings.
    ///   - live: an evening is running now.
    public static func upcoming(
        starts: [Date], lastEvening: Date?, hour: Int, live: Bool,
        now: Date = .now, calendar: Calendar = .current
    ) -> [Date] {
        let time = usualTime(of: starts, now: now, calendar: calendar)
            ?? TimeInterval(hour * 3600)
        let base = calendar.startOfDay(for: lastEvening ?? now)
        let today = calendar.startOfDay(for: now)
        let hadOneToday = lastEvening.map { calendar.isDate($0, inSameDayAs: now) } ?? false

        return fade.compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: base),
                  let at = calendar.date(byAdding: .second, value: Int(time), to: day)
            else { return nil }
            if at <= now { return nil }
            if calendar.isDate(day, inSameDayAs: today), live || hadOneToday { return nil }
            return at
        }
    }

    /// Seconds after midnight, or nil without enough evidence: at least three
    /// evenings in the last 21 days starting within 45 minutes of their usual
    /// time (a circular mean, so 23:30 and 00:30 are an hour apart, not 23).
    public static func usualTime(of starts: [Date], now: Date = .now,
                                 calendar: Calendar = .current) -> TimeInterval? {
        let recent = starts.filter { now.timeIntervalSince($0) <= 21 * 86_400 && $0 <= now }
        guard recent.count >= 3, let mean = TimeOfDay.usual(of: recent, calendar: calendar)
        else { return nil }
        let close = recent.filter { date in
            let c = calendar.dateComponents([.hour, .minute, .second], from: date)
            let s = Double((c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0))
            let gap = abs(s - mean)
            return min(gap, 86_400 - gap) <= 45 * 60
        }
        return close.count >= 3 ? mean : nil
    }
}
