import Foundation

/// The dot week on Home and the four-week grid on screen 10.
///
/// This was the same date arithmetic written twice inside two `View`s, where it
/// could be neither shared nor tested. It is pure functions over plain values
/// so that both can happen.
///
/// Everything here works in distinct `local_date` strings, because a
/// five-person dinner is ONE evening. Counting sessions instead of dates is the
/// bug that would make every number scale with household size.
public enum EveningCalendar {

    public enum Day: Equatable, Sendable {
        case docked
        case missed
        /// A day a rhythm survived. Nothing here produces one: only the
        /// database knows WHICH day a rest day forgave, and `my_rhythm`
        /// returns whether one is available, not when it was spent.
        case rest
        /// Later this week. Drawn as an outline — it hasn't happened yet, and
        /// an un-happened day is not a missed one.
        case future
    }

    /// Monday-first, the current week only.
    public static func week(
        evenings: Set<String>,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [Day] {
        var cal = calendar
        cal.firstWeekday = 2
        guard let week = cal.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let start = cal.startOfDay(for: week.start)
        let dates = dateFormatter(for: cal)
        return (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return .future }
            return classify(day, evenings: evenings, today: today, calendar: cal, dates: dates)
        }
    }

    /// `weeks` whole weeks ending with this one, Monday-first, oldest first.
    ///
    /// Whole weeks rather than a rolling 28 days, so every column is the same
    /// weekday and the last row is the same seven days as the dot week on Home.
    /// The rest of this week is `.future` — drawn, but not as a failure.
    public static func grid(
        evenings: Set<String>,
        weeks: Int = 4,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [Day] {
        var cal = calendar
        cal.firstWeekday = 2
        let days = weeks * 7
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: today),
              let start = cal.date(byAdding: .day, value: -7 * (weeks - 1),
                                   to: cal.startOfDay(for: thisWeek.start))
        else { return [] }
        let dates = dateFormatter(for: cal)
        return (0..<days).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return .future }
            return classify(day, evenings: evenings, today: today, calendar: cal, dates: dates)
        }
    }

    private static func classify(
        _ day: Date, evenings: Set<String>, today: Date,
        calendar: Calendar, dates: DateFormatter
    ) -> Day {
        if calendar.startOfDay(for: day) > calendar.startOfDay(for: today) { return .future }
        return evenings.contains(dates.string(from: day)) ? .docked : .missed
    }

    /// `local_date` is the date in the PERSON'S timezone, so the key for a day
    /// has to be formatted in that timezone too. `PlainDate` formats in UTC —
    /// correct for parsing what Postgres sends back, wrong here, and wrong in a
    /// way that only shows up east of Greenwich, where local midnight is the
    /// previous day in UTC and every dot lands one square early.
    private static func dateFormatter(for calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = calendar.timeZone
        return f
    }

    public static func count(_ days: [Day]) -> Int {
        days.filter { $0 == .docked }.count
    }
}
