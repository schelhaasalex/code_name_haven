import Foundation

/// The mark at the centre of Home, behind the session screen and on the end
/// of an evening: one dot for every evening you've had, tonight's among them.
///
/// It replaced a ticking timer. A number that changes every second rewards
/// glancing at the one screen you're meant to put down; a dot that fills once,
/// at fifteen minutes, doesn't. It is the same mark alone or at a table of
/// five — an evening alone is the same thing, smaller, not a lesser thing.
///
/// A sky: the first evening you ever had is the middle, and each one after
/// lands a little further out, with a place, a size and a brightness of its
/// own. Where a star lands is decided by your account and its number, so it
/// never moves — a sky with more evenings is the same sky, seen from further
/// back — and nobody else's looks like yours.
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

    /// More than a sky this size can show as separate stars: past it, the
    /// words beside the mark carry the number.
    public static let capacity = 1000

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

    /// On Home, between evenings: every evening you've had, and today's
    /// last — filled once today has counted, an outline waiting until then.
    public static func today(total: Int, counted: Bool) -> EveningMarkLayout {
        counted ? .init(count: total, tonight: .counted) : .init(count: total + 1, tonight: .waiting)
    }

    public struct Star: Equatable, Sendable {
        /// Both in -1...1, the centre at 0.
        public let x: Double
        public let y: Double
        /// About 1: most stars a little smaller, a few larger.
        public let size: Double
        /// 0.3...1: most faint, a few bright.
        public let brightness: Double
    }

    /// Where each star sits, oldest first, in a sky drawn from `seed`.
    /// Tonight's is the last.
    public func stars(seed: UInt64) -> [Star] { Self.stars(drawn, seed: seed) }

    /// The sky zoomed to fit: the outermost star touches the edge.
    public static func stars(_ n: Int, seed: UInt64) -> [Star] {
        let raw = (0..<min(max(n, 0), capacity)).map { place($0, seed: seed) }
        let reach = raw.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }.max() ?? 0
        guard reach > 0 else { return raw }
        return raw.map { Star(x: $0.x / reach, y: $0.y / reach, size: $0.size, brightness: $0.brightness) }
    }

    /// Star `i` before zooming, from nothing but `i` and the seed — so it
    /// lands in the same place however many come after it.
    ///
    /// A sunflower's spiral (every star a golden angle round from the last,
    /// at the square root of its number out) spreads stars evenly with no two
    /// close; a nudge in each direction keeps that from reading as a pattern.
    static func place(_ i: Int, seed: UInt64) -> Star {
        var rng = SplitMix(seed ^ (UInt64(i) &* 0x9E37_79B9_7F4A_7C15))
        // Most stars faint and small; about one in ten bright.
        let bright = rng.unit() < 0.1
        let size = bright ? 1.45 + 0.25 * rng.unit() : 0.6 + 0.55 * rng.unit()
        let brightness = bright ? 1 : 0.3 + 0.55 * rng.unit() * rng.unit()
        guard i > 0 else { return Star(x: 0, y: 0, size: size, brightness: brightness) }
        let golden = Double.pi * (3 - 5.0.squareRoot())
        let angle = Double(i) * golden + (rng.unit() - 0.5) * 1.6 / Double(i).squareRoot()
        // The sky's edge is the account's own uneven shape, not a circle.
        var shape = SplitMix(seed)
        let a = shape.unit() * 2 * .pi, b = shape.unit() * 2 * .pi
        let edge = 1 + 0.14 * sin(3 * angle + a) + 0.08 * sin(5 * angle + b)
        let radius = (Double(i) + (rng.unit() - 0.5) * 0.9).squareRoot() * edge
        return Star(x: radius * cos(angle), y: radius * sin(angle), size: size, brightness: brightness)
    }

    /// The seed for an account's sky.
    public static func seed(_ account: UUID?) -> UInt64 {
        guard let account else { return 0 }
        return withUnsafeBytes(of: account.uuid) { bytes in
            bytes.reduce(UInt64(1_469_598_103_934_665_603)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        }
    }
}

/// A small, fixed sequence of numbers from a seed: the same seed, the same sky.
struct SplitMix {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// 0..<1
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
