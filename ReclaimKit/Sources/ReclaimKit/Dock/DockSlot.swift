import Foundation

/// Which slot this phone is in, if any — remembered, because the moment it
/// comes out is answered by something that wasn't there when it went in: a
/// Shortcut, a relaunch, the end of the evening.
///
/// This phone's own fact about itself. Nothing here is sent anywhere.
public enum DockSlot {

    private static let slotKey = "dock.slot"
    private static let sinceKey = "dock.since"

    public static var current: Int? {
        let slot = UserDefaults.standard.integer(forKey: slotKey)
        return Dock.slots.contains(slot) ? slot : nil
    }

    /// When it went in. The charger takes a moment to start after the tag is
    /// read, so "not charging" means nothing for the first little while.
    public static var since: Date? {
        UserDefaults.standard.object(forKey: sinceKey) as? Date
    }

    public static func docked(in slot: Int, at date: Date = .now) {
        UserDefaults.standard.set(slot, forKey: slotKey)
        UserDefaults.standard.set(date, forKey: sinceKey)
    }

    /// Out, and its light with it. Safe to call when nothing is docked — the
    /// charger-disconnected Shortcut runs at the bedside too.
    public static func undock() async {
        guard let slot = current else { return }
        UserDefaults.standard.removeObject(forKey: slotKey)
        UserDefaults.standard.removeObject(forKey: sinceKey)
        await DockLight.shared.settle(slot: slot, on: false)
    }

    /// Whether a phone that isn't charging has been out long enough to say so.
    /// Pure, so the grace can be tested without a phone.
    public static func hasLeft(since: Date?, charging: Bool, now: Date = .now,
                               grace: TimeInterval = 60) -> Bool {
        guard let since, !charging else { return false }
        return now.timeIntervalSince(since) > grace
    }
}
