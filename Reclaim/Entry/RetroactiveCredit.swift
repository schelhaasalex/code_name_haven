import Foundation
import CoreMotion
import ReclaimKit

/// Screen 18 — the answer to "do I have to remember to start it?"
///
/// No. The phone sat still; you say afterwards whether it counted. This is what
/// makes solo use viable before anyone else has the app.
///
/// Queries motion HISTORY rather than running a background task: no battery
/// cost, no always-on sensor, and the permission is Motion & Fitness rather
/// than Always Location. And no notification — the card waits on Home until you
/// next look, because nothing about it is urgent.
enum RetroactiveCredit {

    private static let activity = CMMotionActivityManager()

    static func candidate(excluding known: [Session]) async -> (Date, Date)? {
        guard CMMotionActivityManager.isActivityAvailable() else { return nil }

        let end = Date()
        let start = end.addingTimeInterval(-60 * 60 * 24)

        let runs: [(Date, Date)] = await withCheckedContinuation { continuation in
            activity.queryActivityStarting(from: start, to: end, to: .main) { activities, _ in
                guard let activities else { return continuation.resume(returning: []) }
                var found: [(Date, Date)] = []
                var runStart: Date?
                for item in activities {
                    if item.stationary && item.confidence != .low {
                        if runStart == nil { runStart = item.startDate }
                    } else if let began = runStart {
                        found.append((began, item.startDate))
                        runStart = nil
                    }
                }
                if let began = runStart { found.append((began, end)) }
                continuation.resume(returning: found)
            }
        }

        let minimum: TimeInterval = 15 * 60
        let candidates = runs
            .filter { $0.1.timeIntervalSince($0.0) >= minimum }
            .filter { run in
                // Don't offer something already counted.
                !known.contains { session in
                    session.startedAt < run.1 && (session.endedAt ?? .now) > run.0
                }
            }

        return candidates.max { a, b in
            a.1.timeIntervalSince(a.0) < b.1.timeIntervalSince(b.0)
        }
    }
}

/// Screen 20 is the only optional setup in the product. Declining it is final.
enum OneTapOffer {
    private static let key = "reclaim.onetap.offered"
    static var hasBeenOffered: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
