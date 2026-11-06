import Foundation

/// What the box has become, in the app's words. The database names the stage
/// (`app.place_stage`: fifty evenings is a landmark, twenty a house, five a
/// regular table); the copy says it, so the words can change without a
/// release and without touching the rule.
public enum BoxStage {

    public static func key(_ stage: String) -> String {
        switch stage {
        case "a landmark":      "place.stage.landmark"
        case "a reclaim house": "place.stage.house"
        case "a regular table": "place.stage.regular"
        default:                "place.stage.new"
        }
    }
}
