import AppIntents
import Foundation

/// What the optional "charger disconnected" automation runs: the phone came
/// off the pad in the box, so its light goes out.
///
/// It does NOT end the evening. Lifting a phone out to check one thing is not
/// the end of anything, and only the person gets to say when it is. Docking
/// has no intent of its own — the slot's tag is a link, and `URLRouter`
/// answers it.
public struct UndockIntent: AppIntent {
    public static var title: LocalizedStringResource = "Take my phone out of the box"
    public static var description = IntentDescription("Turns off this phone's light on the box.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await DockSlot.undock()
        return .result()
    }
}
