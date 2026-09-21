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

    /// The longest run worth offering: past the qualifying minimum, and not
    /// overlapping something already counted. Returns nil rather than a
    /// near-miss — this becomes a card on Home, and a wrong one is worse than
    /// none, because the sensor may only ever OFFER.
    public static func candidate(
        runs: [Run],
        existing: [(start: Date, end: Date)],
        minimum: TimeInterval = 15 * 60
    ) -> Run? {
        runs
            .filter { $0.duration >= minimum }
            .filter { run in
                !existing.contains { $0.start < run.end && $0.end > run.start }
            }
            .max { $0.duration < $1.duration }
    }
}
