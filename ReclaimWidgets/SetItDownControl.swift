import WidgetKit
import SwiftUI
import AppIntents
import ReclaimKit

/// Screen 19's other half: starting an evening without unlocking, from Control
/// Centre. iOS 18 — the app runs on 17, so this is gated rather than assumed.
///
/// It draws itself from `SessionFlag` rather than the database, because a
/// control has to render instantly and offline. The flag is a mirror of the
/// truth; the database is the truth.
@available(iOS 18.0, *)
struct SetItDownControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.reclaim.setitdown",
                                   provider: Provider()) { isLive in
            ControlWidgetToggle(t("control.title"),
                                isOn: isLive,
                                action: ToggleSessionIntent()) { running in
                Image(systemName: running ? "moon.stars.fill" : "moon")
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: t("control.title")))
        .description(LocalizedStringResource(stringLiteral: t("control.description")))
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { SessionFlag.isLive }
    }
}
