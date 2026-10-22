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
@MainActor
final class ChargingWatch {

    static let shared = ChargingWatch()

    private let lastKey = "charging.last"
    private let sinceKey = "charging.since"

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { ChargingWatch.shared.look() }
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
        let charging = isCharging
        if charging, !defaults.bool(forKey: lastKey) {
            defaults.set(Date(), forKey: sinceKey)
        }
        defaults.set(charging, forKey: lastKey)
    }
}
