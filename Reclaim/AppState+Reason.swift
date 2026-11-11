import Foundation
import ReclaimKit

/// What the time is for, and the one nudge a day it can earn. Both stay on
/// this phone: the reason in its defaults, the nudges with iOS. None of it
/// gates an evening (rule 7). The box starts one whatever was said, and
/// whether or not anything was.
@MainActor
extension AppState {

    static let reasonKey = "reclaim.reason"
    static let reasonSinceKey = "reclaim.reason.since"
    static let askedKey = "reclaim.reason.asked"
    static let nudgingKey = "reclaim.nudge"

    /// The question's two openings: under the first day that ever counted, or
    /// under the next one for someone who had days before it was asked.
    public enum Asking: Equatable { case first, again }

    /// When it was chosen, for its page's "since".
    public var reasonSince: Date? {
        UserDefaults.standard.object(forKey: Self.reasonSinceKey) as? Date
    }

    /// The receipt's Done. After it, once and never again, the question —
    /// only under a day that counted, and only for someone who hasn't been
    /// asked. "Not now" is an answer: it lives on in Settings and is not
    /// asked again.
    public func doneWithReceipt() {
        let landing = justEnded?.landing
        justEnded = nil
        guard let landing, landing.qualifies, reason == nil,
              !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.askedKey)
        asking = landing.lands && landing.evenings == 1 ? .first : .again
    }

    /// Chosen, changed or cleared, from the question or its page. A change
    /// rewrites nothing that already counted.
    public func choose(_ new: Reason?) {
        guard new != reason else { return }
        reason = new
        UserDefaults.standard.set(new == nil ? nil : Date(), forKey: Self.reasonSinceKey)
        if new == nil { nudging = false }
        Task { await planNudges() }
    }

    /// "Yes, once a day", or its switch on the page. iOS asks here and
    /// nowhere sooner; a no from iOS leaves the switch off and nothing else.
    public func nudge(_ on: Bool) async {
        nudging = on ? await Nudges.allow() : false
        await planNudges()
    }

    /// The week's nudges planned again from what the box has seen lately — or
    /// cleared, for no reason, no yes, or no box. Runs whenever the evenings
    /// are read. A read that came back empty teaches nothing, so the time
    /// stays what it was rather than vanishing offline.
    func planNudges(_ recent: [Session] = []) async {
        let starts = recent.filter(\.qualifying).map(\.startedAt)
        if let minute = NudgeSchedule.minute(of: starts) { nudgeMinute = minute }
        guard nudging, let reason, let box = boxPlace else { await Nudges.clear(); return }
        guard let minute = nudgeMinute else { return }
        let dates = NudgeSchedule.dates(at: minute, from: .now, todayCounts: evenings.contains(PlainDate.local(.now)))
        await Nudges.plan(dates, title: name(of: box), lines: reason.nudges(place: name(of: box)))
    }

    /// `nudgeMinute` as a time on the clock — "6:40 PM" — for the offer and
    /// the page.
    public var nudgeTime: String? {
        nudgeMinute.flatMap { NudgeSchedule.moment($0, on: .now) }.map { Say.time($0) }
    }

    /// The days that counted since the reason was chosen, and the minutes in
    /// them — its page's one sentence. Your own sessions only (rule 1). Nil
    /// until the database answers.
    public func keptSinceReason() async -> (days: Int, minutes: Int)? {
        guard reason != nil, let since = reasonSince,
              let sessions = try? await repo.mySessions(since: since) else { return nil }
        let counted = sessions.filter(\.qualifying)
        return (Set(counted.map(\.localDate)).count, counted.compactMap(\.durationMinutes).reduce(0, +))
    }
}
