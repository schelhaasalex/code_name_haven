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

    static func reschedule(for profile: Profile?) async {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [id])

        guard let profile, profile.nudgeEnabled else { return }
        guard let granted = try? await centre.requestAuthorization(options: [.alert, .sound]),
              granted else { return }

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

    static func silenceForSession() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
