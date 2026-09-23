import Foundation

/// The reasoning behind screen 18, separated from CoreMotion so it can be run
/// over a table of fixtures instead of a phone that has been sitting still.
public enum StationaryRuns {

    /// One stretch where the device reported itself stationary.
    public struct Sample: Equatable, Sendable {
        public let start: Date
        public let stationary: Bool
        public let confident: Bool

        public init(start: Date, stationary: Bool, confident: Bool) {
            self.start = start; self.stationary = stationary; self.confident = confident
        }
    }

    public struct Run: Equatable, Sendable {
        public let start: Date
        public let end: Date
        public init(start: Date, end: Date) { self.start = start; self.end = end }
        public var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Collapse a motion history into the stretches where nothing moved.
    /// Low-confidence samples are ignored rather than treated as movement — a
    /// shrug from the sensor shouldn't split a real evening in two.
    public static func runs(from samples: [Sample], until end: Date) -> [Run] {
        var found: [Run] = []
        var began: Date?
        for sample in samples where sample.confident {
            if sample.stationary {
                if began == nil { began = sample.start }
            } else if let start = began {
                found.append(Run(start: start, end: sample.start))
                began = nil
            }
        }
        if let start = began, start < end { found.append(Run(start: start, end: end)) }
        return found
    }

    /// Mirrors `app.qualifying_minutes()`: fifteen minutes is an evening.
    public static let qualifying: TimeInterval = 15 * 60
    /// Mirrors `app.auto_close_minutes()`. An evening the app offers to invent
    /// may not be longer than one it would have closed FOR you.
    public static let longest: TimeInterval = 180 * 60
    /// The same window `NudgePlan` uses to decide that two evenings happened
    /// at the same time of day.
    public static let recognisable: TimeInterval = 45 * 60

    /// The longest run worth offering — or nothing, which is usually the right
    /// answer.
    ///
    /// A PHONE THAT HASN'T MOVED FOR NINE HOURS IS ASLEEP, and the sensor
    /// cannot tell that from a long dinner: stillness is stillness. Picking
    /// the longest run in a day therefore picks the night, every day, forever.
    /// That was this function, and it offered somebody nine hours of sleep as
    /// an evening the first time the app was opened.
    ///
    /// What separates a night from an evening is not how it starts — both
    /// start in the evening — but how it ENDS. So the question this asks is
    /// not "was the phone still?" but "did this end the way YOUR evenings
    /// end?", and the evenings it compares against are the person's own. With
    /// none to compare against it offers nothing at all, which is the correct
    /// thing to say on a day the app knows nothing about you.
    ///
    /// Every bound here is a rule that already exists somewhere else. None of
    /// them is a number chosen to make this work.
    ///
    /// - Parameter evenings: when your own evenings ENDED — qualifying ones
    ///   you have already had, not sessions still running.
    public static func candidate(
        runs: [Run],
        existing: [(start: Date, end: Date)],
        evenings: [Date],
        minimum: TimeInterval = qualifying,
        maximum: TimeInterval = longest,
        tolerance: TimeInterval = recognisable,
        calendar: Calendar = .current
    ) -> Run? {
        let ends = evenings.map { secondsOfDay($0, calendar: calendar) }
        guard !ends.isEmpty else { return nil }

        return runs
            .filter { $0.duration >= minimum && $0.duration <= maximum }
            .filter { run in
                !existing.contains { $0.start < run.end && $0.end > run.start }
            }
            .filter { run in
                let ending = secondsOfDay(run.end, calendar: calendar)
                return ends.contains { gap(ending, $0) <= tolerance }
            }
            .max { $0.duration < $1.duration }
    }

    private static func secondsOfDay(_ date: Date, calendar: Calendar) -> TimeInterval {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return TimeInterval((parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0))
    }

    /// Clock time is a circle: 23:50 and 00:10 are twenty minutes apart, not
    /// twenty-three hours and forty (`TimeOfDay` makes the same point).
    private static func gap(_ a: TimeInterval, _ b: TimeInterval) -> TimeInterval {
        let raw = abs(a - b)
        return min(raw, 86_400 - raw)
    }
}
