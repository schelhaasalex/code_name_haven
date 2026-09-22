import Foundation
import UserNotifications
import ReclaimKit

/// Scheduled locally. NO REMOTE PUSH anywhere in this product — no APNs
/// certificates, no tokens, no server-side send.
///
/// At most one a day, at a fixed hour, never during a live session, and NEVER a
/// reminder to end one. A buzz telling you to pick up your phone is the app
/// becoming the problem.
enum Notifications {

    private static let id = "reclaim.evening"

    /// Keeps the nudge scheduled, or not. It never asks for permission: that
    /// used to happen here, so the system prompt appeared the moment a new
    /// person signed in — before they had done anything it could be for.
    static func reschedule(for profile: Profile?) async {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [id])

        guard let profile, profile.nudgeEnabled else { return }
        guard await centre.notificationSettings().authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.body = t("notification.nudge")
        content.sound = .default

        var when = DateComponents()
        when.hour = profile.nudgeHour
        when.minute = 0

        try? await centre.add(UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }

    /// Whether the system has never been asked — the only time the app offers.
    static func canOffer() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    /// The system prompt, only ever after someone has said yes in the app.
    static func ask() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func silenceForSession() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
