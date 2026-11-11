import Foundation
import UserNotifications
import ReclaimKit

/// The day's nudge, handed to iOS a week ahead (`NudgeSchedule`). The only
/// file that asks for or schedules a notification (`scripts/shape.sh`): one a
/// day at most, alerts only — no sound, no badge — and never one about ending
/// an evening. A buzz that makes someone pick up their phone is the app
/// becoming the problem. It names the box and nothing else: it lands on a
/// lock screen anyone near the phone can read.
enum Nudges {
    private static let prefix = "reclaim.nudge."
    private static var center: UNUserNotificationCenter { .current() }

    /// iOS's question, for alerts and nothing else. Asked from "Yes, once a
    /// day" and never sooner.
    static func allow() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    /// The week's nudges, replacing whatever was planned. Nothing at all if
    /// iOS has said no since.
    static func plan(_ dates: [Date], place: String, calendar: Calendar = .current) async {
        let lines = NudgeSchedule.lines(place: place)
        await clear()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        for date in dates {
            guard let line = NudgeSchedule.line(lines, on: date, calendar: calendar) else { continue }
            let content = UNMutableNotificationContent()
            content.title = place
            content.body = line
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id(date, calendar), content: content, trigger: trigger))
        }
    }

    static func clear() async {
        let planned = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: planned)
    }

    /// The phone went in: today's is taken back, whether it was still to
    /// come or already on the lock screen.
    static func withdrawToday() {
        let today = [id(.now, .current)]
        center.removePendingNotificationRequests(withIdentifiers: today)
        center.removeDeliveredNotifications(withIdentifiers: today)
    }

    private static func id(_ date: Date, _ calendar: Calendar) -> String {
        prefix + PlainDate.local(date, calendar: calendar)
    }
}
