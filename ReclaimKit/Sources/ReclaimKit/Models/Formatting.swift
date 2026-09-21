import Foundation

public enum Say {
    private static let words = ["Nobody", "Just you", "Two of you", "Three of you",
                               "Four of you", "Five of you", "Six of you",
                               "Seven of you", "Eight of you", "Nine of you"]

    /// "Three of you" — spelled out to nine, then numeric. Warmth over precision.
    public static func count(_ n: Int) -> String {
        n >= 0 && n < words.count ? words[n] : "\(n) of you"
    }

    private static let smallNumbers = ["no", "one", "two", "three", "four", "five",
                                       "six", "seven", "eight", "nine", "ten",
                                       "eleven", "twelve"]

    public static func number(_ n: Int) -> String {
        n >= 0 && n < smallNumbers.count ? smallNumbers[n] : "\(n)"
    }

    /// "2h 14m", "48m". Never "0h 48m".
    public static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// "an hour and 40" — for prose, where a bare "100m" reads as a readout.
    /// Small numbers are spelled out; past twelve digits are less fussy than
    /// "forty-three".
    public static func spokenDuration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, 1): return "a minute"
        case (0, let m): return "\(number(m)) minutes"
        case (1, 0): return "an hour"
        case (1, let m): return "an hour and \(number(m))"
        case (let h, 0): return "\(number(h)) hours"
        case (let h, let m): return "\(number(h)) hours and \(number(m))"
        }
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
