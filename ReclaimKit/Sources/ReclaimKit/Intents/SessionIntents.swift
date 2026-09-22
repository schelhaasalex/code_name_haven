import ActivityKit
import AppIntents
import Foundation

/// The two intents everything else is a thin wrapper over: Siri, the Action
/// Button, a Shortcut, a Control Centre control, the NFC tag, and the End
/// button on the Live Activity.
///
/// The product's claim is that a session starts and ends without opening the
/// app. These are how.
///
/// All three are `LiveActivityIntent`s, and that is load-bearing rather than
/// descriptive. A widget or control runs a plain intent in its own extension,
/// where there is no repository and no signed-in session — so the End button
/// and the Control Centre toggle did nothing. A `LiveActivityIntent` runs in
/// the app's process, launched in the background if it has to be, and is also
/// what lets an evening started from Siri or a control start its Live
/// Activity at all. The Siri phrases live in the app target
/// (`ReclaimShortcuts`): App Shortcuts are only read from there.

/// Set by the app at launch so intents can reach the database without booting
/// the whole SwiftUI stack.
public enum IntentEnvironment {
    nonisolated(unsafe) public static var repository: (any Repository)?
    nonisolated(unsafe) public static var onSessionChanged: (@Sendable () async -> Void)?
}

public struct StartSessionIntent: AppIntent, LiveActivityIntent {
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

/// What the Control Centre toggle runs. iOS 18 only — the app's own floor is
/// 17, and a control is not worth raising it for.
@available(iOS 18.0, *)
public struct ToggleSessionIntent: SetValueIntent, LiveActivityIntent {
    public static var title: LocalizedStringResource = "Set it down"

    @Parameter(title: "Running")
    public var value: Bool

    public init() {}

    public func perform() async throws -> some IntentResult {
        guard let repo = IntentEnvironment.repository else { return .result() }
        if value {
            _ = try await repo.startOrJoin(place: nil, source: .control)
        } else {
            try await repo.endSession(nil)
            await ReclaimActivity.endAll()
        }
        SessionFlag.isLive = value
        await IntentEnvironment.onSessionChanged?()
        return .result()
    }
}

public struct EndSessionIntent: AppIntent, LiveActivityIntent {
    public static var title: LocalizedStringResource = "End the evening"
    public static var description = IntentDescription("Ends the session that's running.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        guard let repo = IntentEnvironment.repository else { return .result() }
        try await repo.endSession(nil)
        // Before anything else, and without asking the app to do it: this
        // runs in a process that was launched to answer the button and may
        // know nothing about the evening it is ending. See `ReclaimActivity`.
        await ReclaimActivity.endAll()
        SessionFlag.isLive = false
        await IntentEnvironment.onSessionChanged?()
        return .result()
    }
}
