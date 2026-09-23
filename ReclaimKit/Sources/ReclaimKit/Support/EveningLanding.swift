import Foundation

/// Screen 8's moment: tonight arriving in your week, rather than already being
/// in it when the screen appears.
///
/// The end screen used to draw everything at once and read the week from
/// `AppState.evenings` — which, just after ending, is the week BEFORE tonight,
/// because the reload that counts it hasn't landed. So the line that should
/// have been the reward was usually missing, and nothing ever visibly changed.
/// This keeps the week as it was and the evening it adds, both known at the
/// moment of ending, so the screen can show one becoming the other.
///
/// Knowledge test: the database credited the minutes and set the local date;
/// fifteen minutes is `app.qualifying_minutes()`. Nothing here is a guess.
public struct EveningLanding: Equatable, Sendable {

    /// Mirrors `app.qualifying_minutes()`.
    public static let qualifyingMinutes = 15

    /// The evenings known when it ended — tonight not among them, unless an
    /// earlier session today already counted.
    public let before: Set<String>
    /// The evening this ending adds. Nil when it was too short to count, or
    /// when today had already counted — then nothing lands, and nothing
    /// pretends to.
    public let tonight: String?
    public let qualifies: Bool

    public init(known: Set<String>, localDate: String, minutes: Int) {
        before = known
        qualifies = minutes >= Self.qualifyingMinutes
        tonight = qualifies && !known.contains(localDate) ? localDate : nil
    }

    public var after: Set<String> {
        guard let tonight else { return before }
        return before.union([tonight])
    }

    // MARK: - The beats, in seconds
    // A delay is a decision (see `SplashChoreography`): here, not in the view.

    /// A breath before anything moves, so the screen arrives first.
    public static let settle = 0.35
    /// The duration counting up to what was credited.
    public static let counting = 1.1
    /// Between one person's dot and the next.
    public static let perPerson = 0.16
    /// Between the people and tonight's dot filling in.
    public static let beforeDot = 0.45
    /// Between the dot and the line about the week.
    public static let beforeLine = 0.5

    /// The minutes shown at each step of the count, ending exactly on
    /// `minutes`. Never more than `steps` of them, so a four-hour evening
    /// takes as long to count as a forty-minute one.
    public static func counts(to minutes: Int, steps: Int = 24) -> [Int] {
        guard minutes > 0 else { return [0] }
        let n = min(minutes, max(1, steps))
        return (1...n).map { minutes * $0 / n }
    }
}
