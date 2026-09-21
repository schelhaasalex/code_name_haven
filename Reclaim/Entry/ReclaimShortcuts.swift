import AppIntents
import ReclaimKit

/// Free Siri, with no setup: these appear in the Shortcuts app by themselves.
/// Chaining to "Set Focus" still needs a user-built shortcut — App Shortcuts
/// can only contain our own actions.
///
/// In the app target on purpose. App Shortcuts are only read from the app
/// itself — declared in ReclaimKit, the intents were registered but the
/// phrases never were (`autoShortcuts` came out empty), so "Set my phone down
/// with Reclaim" reached nothing. `scripts/shape.sh` keeps it here.
struct ReclaimShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
