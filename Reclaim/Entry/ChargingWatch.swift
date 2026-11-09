import Foundation
import UIKit
import ReclaimKit

/// When this phone started charging — the half of "was that me?" the box
/// can't answer.
///
/// iOS only tells a running app about the battery, so the last state seen is
/// kept: a phone that was unplugged when the app last looked and is charging
/// now has just started, as far as this phone can know, even if the moment
/// itself happened while the app was asleep.
///
/// The other way round it can't know: charging when the app last looked and
/// charging now may be one stretch, or two with an unplug between that
/// nobody saw. `unbroken` says whether the app was watching closely enough
/// to tell — it looks on every change, and on the way in and out of the
/// background, so a gap longer than `gap` between looks is time it slept.
@MainActor
final class ChargingWatch {

    static let shared = ChargingWatch()

    private let lastKey = "charging.last"
    private let sinceKey = "charging.since"
    private let seenKey = "charging.seen"
    private let unbrokenKey = "charging.unbroken"

    /// Longer than this between two looks at a charging phone, and the app
    /// wasn't watching in between.
    private let gap: TimeInterval = 60

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { ChargingWatch.shared.look() }
        }
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { ChargingWatch.shared.look() }
            }
        }
        look()
    }

    var isCharging: Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    /// When the current stretch of charging began, if it is one.
    var since: Date? {
        look()
        return isCharging ? UserDefaults.standard.object(forKey: sinceKey) as? Date : nil
    }

    /// Whether the app watched the whole of this stretch of charging, so
    /// "already charging" can be believed.
    var unbroken: Bool {
        look()
        return UserDefaults.standard.object(forKey: unbrokenKey) as? Bool ?? false
    }

    /// The pad takes a moment to start after the phone lands — often longer
    /// than the box's sensor. Waits up to `seconds` for it.
    func charging(within seconds: Double) async -> Bool {
        look()
        if isCharging { return true }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))
            look()
            if isCharging { return true }
        }
        return false
    }

    private func look() {
        let defaults = UserDefaults.standard
        let charging = isCharging, now = Date()
        if charging, !defaults.bool(forKey: lastKey) {
            defaults.set(now, forKey: sinceKey)
            defaults.set(true, forKey: unbrokenKey)
        } else if charging, let seen = defaults.object(forKey: seenKey) as? Date,
                  now.timeIntervalSince(seen) > gap {
            defaults.set(false, forKey: unbrokenKey)
        }
        defaults.set(charging, forKey: lastKey)
        defaults.set(now, forKey: seenKey)
    }
}
