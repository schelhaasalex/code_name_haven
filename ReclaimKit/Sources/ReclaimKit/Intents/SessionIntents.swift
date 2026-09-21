import AppIntents
import Foundation

/// The two intents everything else is a thin wrapper over: Siri, the Action
/// Button, a Shortcut, a Control Centre control, the NFC tag, and the End
/// button on the Live Activity.
///
/// The product's claim is that a session starts and ends without opening the
/// app. These are how.

/// Set by the app at launch so intents can reach the database without booting
/// the whole SwiftUI stack.
public enum IntentEnvironment {
    nonisolated(unsafe) public static var repository: (any Repository)?
    nonisolated(unsafe) public static var onSessionChanged: (@Sendable () async -> Void)?
}

public struct StartSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set my phone down"
    public static var description = IntentDescription("Starts an evening.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Place")
    public var placeId: String?

    public init() {}
    public init(placeId: String? = nil) { self.placeId = placeId }

    public func perform() async throws -> some IntentResult {
        guard let repo = IntentEnvironment.repository else { return .result() }
        let place = placeId.flatMap(UUID.init(uuidString:))
        _ = try await repo.startOrJoin(place: place, source: .shortcut)
        await IntentEnvironment.onSessionChanged?()
        return .result()
    }
}

public struct EndSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "End the evening"
    public static var description = IntentDescription("Ends the session that's running.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        guard let repo = IntentEnvironment.repository else { return .result() }
        try await repo.endSession(nil)
        await IntentEnvironment.onSessionChanged?()
        return .result()
    }
}

/// Free Siri, with no setup: these appear in the Shortcuts app by themselves.
/// Chaining to "Set Focus" still needs a user-built shortcut — App Shortcuts
/// can only contain our own actions.
public struct ReclaimShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start a \(.applicationName) session",
                "Set my phone down with \(.applicationName)",
                "\(.applicationName) this evening"
            ],
            shortTitle: "Set it down",
            systemImageName: "moon.stars"
        )
        AppShortcut(
            intent: EndSessionIntent(),
            phrases: ["End my \(.applicationName) session"],
            shortTitle: "End",
            systemImageName: "checkmark.circle"
        )
    }
}
