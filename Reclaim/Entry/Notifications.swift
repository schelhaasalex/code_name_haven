import Foundation
import UserNotifications
import ReclaimKit

/// Scheduled locally. NO REMOTE PUSH anywhere in this product — no APNs
/// certificates, no tokens, no server-side send.
///
/// At most one a day, never during a live session, never on a day that already
/// had an evening, fading to nothing when someone drifts away (`NudgePlan`), and
/// NEVER a reminder to end one. A buzz telling you to pick up your phone is the app
/// becoming the problem.
enum Notifications {

    private static let prefix = "reclaim.nudge."
    /// The repeating 7pm notification this replaced; cleared wherever it was left.
    private static let legacy = "reclaim.evening"

    /// Replaces whatever is waiting with these nudges. It never asks for
    /// permission — that used to happen here, so the system prompt appeared the
    /// moment a new person signed in. Quiet on arrival: no sound.
    static func schedule(_ dates: [Date], body: String) async {
        await clear()
        let centre = UNUserNotificationCenter.current()
        guard !dates.isEmpty,
              await centre.notificationSettings().authorizationStatus == .authorized else { return }

        for (i, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.body = body
            let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            try? await centre.add(UNNotificationRequest(
                identifier: prefix + String(i),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        }
    }

    static func clear() async {
        let centre = UNUserNotificationCenter.current()
        let ids = await centre.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(prefix) || $0 == legacy }
        centre.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Whether the system has never been asked — the only time the app offers.
    static func canOffer() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    /// The system prompt, only ever after someone has said yes in the app.
    static func ask() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    }

    /// Never buzz during a session. Scheduled again when it ends.
    static func silenceForSession() {
        Task { await clear() }
    }
}
