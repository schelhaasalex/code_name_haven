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
            face(context.state)
                .activityBackgroundTint(Palette.nightCard)
                .activitySystemActionForegroundColor(Palette.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RingMark(stage: context.state.stage, memberCount: context.state.memberCount, size: 34)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline(context.state))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.cream)
                            .lineLimit(1)
                        Text(since(context.state))
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
    private func face(_ state: ReclaimActivityAttributes.ContentState) -> some View {
        if #available(iOS 18.0, *) {
            ActivityFace(lockScreen: lockScreen(state), wrist: WristActivity(state: state))
        } else {
            lockScreen(state)
        }
    }

    /// No ticking digits. A face-down phone gets picked up and read here, so
    /// a timer on the lock screen undid everything the session screen stopped
    /// doing. It says what you're doing, where, and since when.
    private func lockScreen(_ state: ReclaimActivityAttributes.ContentState) -> some View {
        HStack(spacing: 16) {
            RingMark(stage: state.stage, memberCount: state.memberCount, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(headline(state))
                    .font(Type.display(22))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                Text(since(state))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.dust)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    /// The same headline as the session screen: where the evening has got
    /// to when alone, the count when it's earned it.
    private func headline(_ state: ReclaimActivityAttributes.ContentState) -> String {
        state.memberCount <= 1 ? EveningCharge.line(stage: state.stage)
                               : t("lockscreen.together", "count", Say.count(state.memberCount))
    }

    private func since(_ state: ReclaimActivityAttributes.ContentState) -> String {
        t("lockscreen.since", "place", state.placeName ?? t("box.unnamed"),
          "time", Say.time(state.startedAt))
    }
}
