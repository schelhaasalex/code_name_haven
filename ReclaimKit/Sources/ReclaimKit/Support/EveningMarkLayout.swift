import Foundation

/// The mark behind the session screen and on the end of an evening: one dot
/// for every evening you've had, tonight's among them.
///
/// It replaced a ticking timer. A number that changes every second rewards
/// glancing at the one screen you're meant to put down; a dot that fills once,
/// at fifteen minutes, doesn't. It is the same mark alone or at a table of
/// five — an evening alone is the same thing, smaller, not a lesser thing.
///
/// Dots sit on rings outward from the centre: the first evening you ever had
/// is the middle, and tonight's is the newest on the outside.
public struct EveningMarkLayout: Equatable, Sendable {

    public enum Tonight: Equatable, Sendable {
        /// Drawn as an outline. Tonight hasn't counted yet — under fifteen
        /// minutes, it is kept rather than counted.
        case waiting
        /// Filled. Tonight counts, or today already did.
        case counted
    }

    /// Dots, tonight's included.
    public let count: Int
    public let tonight: Tonight

    public init(count: Int, tonight: Tonight) {
        self.count = max(1, count)
        self.tonight = tonight
    }

    /// Five rings around the centre: 1 + 6 + 12 + 18 + 24 + 30. Past this the
    /// oldest full rings will need to merge into solid circles, so that
    /// nothing is ever taken away; until then this is a bound, and the words
    /// beside the mark carry the real number.
    public static let rings = 5
    public static let capacity = 91

    public var drawn: Int { min(count, Self.capacity) }

    /// While an evening runs. `alreadyCounted` is today having counted
    /// before this session began — then tonight's dot is that one, already
    /// filled, rather than a second.
    public static func during(
        total: Int, alreadyCounted: Bool, elapsed: TimeInterval
    ) -> EveningMarkLayout {
        if alreadyCounted { return .init(count: total, tonight: .counted) }
        let counted = elapsed >= Double(EveningLanding.qualifyingMinutes * 60)
        return .init(count: total + 1, tonight: counted ? .counted : .waiting)
    }

    public struct Point: Equatable, Sendable {
        /// Both in -1...1, the centre at 0.
        public let x: Double
        public let y: Double
    }

    /// Where each dot sits, oldest first. Tonight's is the last.
    public var points: [Point] { Self.points(drawn) }

    public static func points(_ n: Int) -> [Point] {
        var out: [Point] = []
        var ring = 0
        while out.count < n, ring <= rings {
            let seats = ring == 0 ? 1 : 6 * ring
            let radius = Double(ring) / Double(rings)
            for k in 0..<min(seats, n - out.count) {
                // Each ring turned a little from the last, so the dots don't
                // line up into spokes.
                let angle = 2 * Double.pi * Double(k) / Double(seats) + Double(ring) * 0.5
                out.append(Point(x: radius * cos(angle), y: radius * sin(angle)))
            }
            ring += 1
        }
        return out
    }
}
