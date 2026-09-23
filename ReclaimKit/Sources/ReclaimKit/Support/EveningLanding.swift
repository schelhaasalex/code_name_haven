import Foundation

/// Screen 8's moment: tonight's dot filling in among your evenings, rather
/// than the screen appearing with it already there.
///
/// Everything here is known at the moment of ending, so nothing waits on a
/// reload. The screen used to read the week from `AppState.evenings` before
/// the reload that counts tonight had landed, and the line that was meant to
/// be the reward was usually missing on exactly the evening it was for.
///
/// Knowledge test: the database credited the minutes and set the local date;
/// fifteen minutes is `app.qualifying_minutes()`. Nothing here is a guess.
public struct EveningLanding: Equatable, Sendable {

    /// Mirrors `app.qualifying_minutes()`.
    public static let qualifyingMinutes = 15

    /// Your evenings before this one ended — tonight not among them, unless
    /// an earlier session today already counted.
    public let total: Int
    public let first: String?
    public let localDate: String
    /// Today had already counted before this ended. An evening is a day, so
    /// nothing new lands, and nothing pretends to.
    public let alreadyCounted: Bool
    public let qualifies: Bool

    public init(total: EveningTotal, known: Set<String>, localDate: String, minutes: Int) {
        self.total = total.count
        self.first = total.first
        self.localDate = localDate
        self.alreadyCounted = known.contains(localDate)
        self.qualifies = minutes >= Self.qualifyingMinutes
    }

    /// Tonight adds an evening.
    public var lands: Bool { qualifies && !alreadyCounted }

    /// The mark as the evening ended: tonight's dot still an outline, unless
    /// today had already counted.
    public var before: EveningMarkLayout {
        alreadyCounted ? .init(count: total, tonight: .counted)
                       : .init(count: total + 1, tonight: .waiting)
    }

    /// And once it has landed. A short one stays an outline: kept, not counted.
    public var after: EveningMarkLayout {
        lands ? .init(count: before.count, tonight: .counted) : before
    }

    /// The number beside the mark once it has landed.
    public var evenings: Int { total + (lands ? 1 : 0) }

    /// The first evening — tonight's, if tonight was the first.
    public var since: String? { first ?? (lands ? localDate : nil) }

    /// Between the screen arriving and tonight's dot filling in: long enough
    /// to read the time first. A delay is a decision, so it lives here.
    public static let pause = 0.7
}
