import Foundation

/// What the box has become, in the app's words. The database names the stage
/// (`app.place_stage`, 0022: a week is broken in, a month settled in, a
/// hundred days seasoned, a year part of the house); the copy says it, so the
/// words can change without a release and without touching the rule.
///
/// Days are the box's: any phone, fifteen minutes. One person on their own
/// moves it exactly as a family does, and it only ever goes forward.
public enum BoxStage {

    /// The day each stage begins, in order. `app.place_stage` counts the same;
    /// `scripts/shape.sh` checks the two agree.
    public static let days = [7, 30, 100, 365]

    public static func key(_ stage: String) -> String {
        switch stage {
        case "part of the house": "place.stage.house"
        case "seasoned":          "place.stage.seasoned"
        case "settled in":        "place.stage.settled"
        case "broken in":         "place.stage.broken"
        default:                  "place.stage.way"
        }
    }

    /// How many stages a box with this many days has reached: 0 before the
    /// first, `days.count` at the last.
    public static func reached(evenings: Int) -> Int {
        days.filter { evenings >= $0 }.count
    }

    /// Where the box stands on the track, 0 at day one and 1 at the last
    /// stage. The marks are spaced evenly rather than by day, so a year isn't
    /// a far-off speck and the first week isn't a crease at the start.
    public static func position(evenings: Int) -> Double {
        let marks = [0] + days
        let i = reached(evenings: evenings)
        guard i < days.count else { return 1 }
        let from = marks[i], to = marks[i + 1]
        let within = Double(max(evenings, 0) - from) / Double(to - from)
        return (Double(i) + within) / Double(days.count)
    }
}
