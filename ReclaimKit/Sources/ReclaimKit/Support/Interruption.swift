import Foundation

/// The four screens you never navigate to — 13, 14, 18 and 20. They appear over
/// Home when there is something to say, at most one per launch.
///
/// None of them is a notification. They wait until the person next looks,
/// because nothing about any of them is urgent.
public enum Interruption: Identifiable, Equatable, Sendable {
    case autoClosed(Session)              // 13 — "we closed this one for you"
    case rhythmEnded(Rhythm)              // 14 — "that rhythm ended"
    case countThat(from: Date, to: Date)  // 18 — the phone sat still; did it count?
    case makeItOneTap                     // 20 — the only optional setup

    public var id: String {
        switch self {
        case .autoClosed(let s):   "auto-\(s.id)"
        case .rhythmEnded:         "rhythm-ended"
        case .countThat(let f, _): "count-\(f.timeIntervalSince1970)"
        case .makeItOneTap:        "one-tap"
        }
    }
}

extension Interruption {

    /// Screen 20 arrives after five evenings, per the brief. Evenings, not
    /// sessions — five people at one dinner is one.
    public static let oneTapAfterEvenings = 5

    /// Which one surfaces when several qualify.
    ///
    /// The order is the order of debt owed to the person: something we did on
    /// their behalf (13) before something that happened to them (14) before
    /// something we are guessing at (18) before something we want (20).
    ///
    /// Pure so the precedence can be tested without a phone, a sensor or a
    /// network. `stationary` is a closure rather than a value because asking it
    /// is what prompts for Motion & Fitness — nothing should trigger that
    /// permission on a launch where something louder was already waiting.
    ///
    /// - Parameters:
    ///   - recent: the person's own sessions over the last day or two.
    ///   - evenings: distinct qualifying `local_date`s — NOT a session count.
    public static func first(
        recent: [Session],
        rhythm: Rhythm,
        evenings: Int,
        oneTapOffered: Bool,
        stationary: () async -> StationaryRuns.Run?
    ) async -> Interruption? {
        if let closed = recent.filter(\.autoClosed).max(by: { $0.startedAt < $1.startedAt }) {
            return .autoClosed(closed)
        }
        // A run of one day isn't a rhythm, and telling someone it ended would
        // be inventing a loss they never felt.
        if rhythm.state == .between, rhythm.longestRunDays > 1 {
            return .rhythmEnded(rhythm)
        }
        if let run = await stationary() {
            return .countThat(from: run.start, to: run.end)
        }
        if evenings >= oneTapAfterEvenings, !oneTapOffered {
            return .makeItOneTap
        }
        return nil
    }
}
