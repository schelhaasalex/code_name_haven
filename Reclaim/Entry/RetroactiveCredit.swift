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
///
/// The reasoning itself is in `StationaryRuns`, where it can be tested against
/// fixtures. What's left here is CoreMotion and nothing else.
enum RetroactiveCredit {

    private static let activity = CMMotionActivityManager()

    /// `known` is what must not be offered twice; `mine` is what an evening of
    /// yours looks like — the ended, qualifying ones, which is how the run
    /// that was really sleep is told apart from the one that was really
    /// dinner. With none of them, nothing is offered at all.
    static func candidate(excluding known: [Session], mine: [Session]) async -> StationaryRuns.Run? {
        guard CMMotionActivityManager.isActivityAvailable() else { return nil }

        let end = Date()
        let start = end.addingTimeInterval(-60 * 60 * 24)
        let samples = await samples(from: start, to: end)

        return StationaryRuns.candidate(
            runs: StationaryRuns.runs(from: samples, until: end),
            existing: known.map { (start: $0.startedAt, end: $0.endedAt ?? end) },
            evenings: mine.filter(\.qualifying).compactMap(\.endedAt))
    }

    private static func samples(from start: Date, to end: Date) async -> [StationaryRuns.Sample] {
        await withCheckedContinuation { continuation in
            activity.queryActivityStarting(from: start, to: end, to: .main) { activities, _ in
                continuation.resume(returning: (activities ?? []).map {
                    StationaryRuns.Sample(start: $0.startDate,
                                          stationary: $0.stationary,
                                          confident: $0.confidence != .low)
                })
            }
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
