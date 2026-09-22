import Foundation

/// How the app says numbers, people and time. The words themselves live in
/// `copy/strings.json` under `say.*`, like every other string (rule 2) — this
/// only decides which one to use.
public enum Say {

    /// "Three of you" — spelled out to nine, then numeric. Warmth over precision.
    public static func count(_ n: Int) -> String {
        let words = Copy.list("say.count")
        return n >= 0 && n < words.count ? words[n] : t("say.count.more", "count", "\(n)")
    }

    /// "three" — lowercase, for the middle of a sentence. A template that
    /// opens with `{count}` is capitalised by `t()`.
    public static func number(_ n: Int) -> String {
        let words = Copy.list("say.number")
        return n >= 0 && n < words.count ? words[n] : "\(n)"
    }

    /// "Maya", "Maya and Dad", "Maya, Dad and Sam".
    ///
    /// Only ever people who ARE here. Nobody is named for not having arrived,
    /// so there is no "and 2 others still to come" form of this function and
    /// there never will be.
    public static func names(_ people: [String]) -> String {
        switch people.count {
        case 0:  ""
        case 1:  people[0]
        case 2:  t("say.names.two", "first", people[0], "second", people[1])
        default: t("say.names.many",
                   "list", people.dropLast().joined(separator: t("say.names.separator")),
                   "last", people[people.count - 1])
        }
    }

    /// "2h 14m", "48m". Never "0h 48m".
    public static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return t("say.duration.minutes", "m", "\(m)") }
        if m == 0 { return t("say.duration.hours", "h", "\(h)") }
        return t("say.duration.both", "h", "\(h)", "m", "\(m)")
    }

    /// "an hour and 40" — for prose, where a bare "100m" reads as a readout.
    /// Small numbers are spelled out; past twelve digits are less fussy than
    /// "forty-three".
    public static func spokenDuration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, 1):         return t("say.spoken.minute")
        case (0, let m):     return t("say.spoken.minutes", "m", number(m))
        case (1, 0):         return t("say.spoken.hour")
        case (1, let m):     return t("say.spoken.hour.minutes", "m", number(m))
        case (let h, 0):     return t("say.spoken.hours", "h", number(h))
        case (let h, let m): return t("say.spoken.hours.minutes", "h", number(h), "m", number(m))
        }
    }

    /// "Monday evening". Replaces an eyebrow that said "Tuesday evening" every
    /// day, because the mockup did. Before five in the morning it is still the
    /// night before — an evening that ends at one belongs to the day it
    /// started, the same way `local_date` credits it.
    public static func partOfDay(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let part: String
        var day = date
        switch hour {
        case 5..<12:  part = "time.morning"
        case 12..<17: part = "time.afternoon"
        case 17..<22: part = "time.evening"
        default:
            part = "time.night"
            if hour < 5 { day = calendar.date(byAdding: .day, value: -1, to: date) ?? date }
        }
        let weekday = DateFormatter()
        weekday.calendar = calendar
        weekday.timeZone = calendar.timeZone
        weekday.locale = calendar.locale ?? .current
        weekday.setLocalizedDateFormatFromTemplate("EEEE")
        return t(part, "day", weekday.string(from: day))
    }

    /// "7 PM", "19:00" — an hour of the day in the phone's own style. The
    /// nudge hour used to be written into Settings as "7:00pm", whatever it was.
    public static func hour(_ hour: Int, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = calendar.locale ?? .current
        f.setLocalizedDateFormatFromTemplate("j")
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour)) ?? .now
        return f.string(from: date)
    }

    public static func clock(_ elapsed: TimeInterval) -> String {
        let s = max(0, Int(elapsed))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// The month a place became itself. "March".
    ///
    /// Formats in UTC because `PlainDate` parses in UTC. Without that, the
    /// first of a month parsed as midnight UTC and rendered in a western
    /// timezone comes back as the month before.
    public static func month(from isoDate: String?) -> String? {
        guard let isoDate, let date = PlainDate.date(from: isoDate) else { return nil }
        return monthFormatter.string(from: date)
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "LLLL"
        return f
    }()
}

/// Postgres `date` columns come back as "yyyy-MM-dd" with no zone.
public enum PlainDate {
    public static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    public static func string(from date: Date) -> String { formatter.string(from: date) }
    public static func date(from string: String) -> Date? { formatter.date(from: string) }
}
