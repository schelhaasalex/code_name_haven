import Foundation

/// "All of them around 7:40" — the one line on screen 21 that the app worked
/// out rather than was told.
public enum TimeOfDay {

    /// The usual time of day among these moments, as seconds after midnight.
    ///
    /// Clock time is a circle, so this is a circular mean rather than an
    /// average of the minutes. Eleven at night and one in the morning are two
    /// hours apart and their usual time is midnight; averaging the raw numbers
    /// answers midday, which is not merely imprecise — it is the opposite side
    /// of the clock, and it would put "around 12:00" under a photo of a dinner.
    ///
    /// Returns nil when the times are spread evenly enough that no hour is the
    /// usual one. Saying nothing is the correct answer there; the screen simply
    /// leaves the line out.
    public static func usual(of dates: [Date], calendar: Calendar = .current) -> TimeInterval? {
        guard !dates.isEmpty else { return nil }
        let day = 86_400.0
        var x = 0.0, y = 0.0

        for date in dates {
            let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
            let seconds = Double((parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60
                                 + (parts.second ?? 0))
            let angle = seconds / day * 2 * .pi
            x += cos(angle)
            y += sin(angle)
        }

        guard hypot(x, y) > 1e-9 else { return nil }
        var mean = atan2(y, x)
        if mean < 0 { mean += 2 * .pi }
        return mean / (2 * .pi) * day
    }
}
