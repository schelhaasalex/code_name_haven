import SwiftUI
import WidgetKit
import ActivityKit
import ReclaimKit

/// Screen 7 — the evening on the lock screen, started by the box (by push,
/// when the box woke the app in the background) and stepped by the server.
///
/// Nothing to press. The box is the only switch: taking the phone out ends
/// the evening, and the activity with it.
struct ReclaimLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReclaimActivityAttributes.self) { context in
            face(context.state, stale: context.isStale)
                .activityBackgroundTint(Palette.nightCard)
                .activitySystemActionForegroundColor(Palette.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RingMark(stage: context.state.stage, memberCount: context.state.memberCount, size: 34)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        headlineText(context.state, stale: context.isStale)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.cream)
                            .lineLimit(1)
                        Text(subline(context.state))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.dust)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                RingMark(stage: context.state.stage, size: 16)
            } compactTrailing: {
                // Together, how many; alone, nothing. Never digits that tick.
                if context.state.memberCount > 1 {
                    Text(String(context.state.memberCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ember)
                }
            } minimal: {
                RingMark(stage: context.state.stage, size: 16)
            }
        }
    }

    /// On iOS 18 the same activity can show on a paired Watch, where it asks
    /// for the small family. Before 18 there is no family to ask about.
    @ViewBuilder
    private func face(_ state: ReclaimActivityAttributes.ContentState, stale: Bool) -> some View {
        if #available(iOS 18.0, *) {
            ActivityFace(lockScreen: lockScreen(state, stale: stale),
                         wrist: WristActivity(state: state, stale: stale))
        } else {
            lockScreen(state, stale: stale)
        }
    }

    /// No ticking digits. The lock screen is what a phone taken out of the box
    /// shows first, so a timer here undid everything the session screen
    /// stopped doing. It says what you're doing, where, and since when — except for
    /// the five seconds after the phone comes out, when the one thing worth
    /// knowing is when it ends, and that putting it back carries on.
    ///
    /// Past the cap, and the server's ending never arrived: it says what the
    /// server did, quieter.
    private func lockScreen(_ state: ReclaimActivityAttributes.ContentState, stale: Bool) -> some View {
        HStack(spacing: 16) {
            RingMark(stage: state.stage, memberCount: state.memberCount, size: 44)
                .opacity(stale ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 5) {
                headlineText(state, stale: stale)
                    .font(Type.display(22))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                Text(subline(state))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.dust)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    /// The same headline as the session screen and the wrist: where the
    /// evening has got to, alone or together. Who's there is the line below.
    private func headline(_ state: ReclaimActivityAttributes.ContentState) -> String {
        EveningCharge.line(stage: state.stage)
    }

    /// Counting down while the phone is out; otherwise the evening's line.
    @ViewBuilder
    private func headlineText(_ state: ReclaimActivityAttributes.ContentState, stale: Bool) -> some View {
        if stale {
            Text(t("lockscreen.closed"))
        } else if let end = state.endingAt, end > .now {
            Text("\(t("leaving.headline")) \(Text(timerInterval: Date.now...end, countsDown: true))")
                .monospacedDigit()
        } else {
            Text(headline(state))
        }
    }

    private func subline(_ state: ReclaimActivityAttributes.ContentState) -> String {
        if let end = state.endingAt, end > .now { return t("leaving.body") }
        return since(state)
    }

    /// Together, how many; alone, which box — and with no box to name, only
    /// since when, rather than a name for a box that doesn't exist.
    private func since(_ state: ReclaimActivityAttributes.ContentState) -> String {
        let time = Say.time(state.startedAt)
        if state.memberCount > 1 {
            return t("evening.together", "count", Say.count(state.memberCount), "time", time)
        }
        guard let place = state.placeName else { return t("wrist.since", "time", time) }
        return t("lockscreen.since", "place", place, "time", time)
    }
}
