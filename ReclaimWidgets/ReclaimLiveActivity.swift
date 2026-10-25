import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents
import ReclaimKit

/// Screens 7 and 19 — the reason the deployment target is iOS 17.
///
/// The End button is an App Intent running IN the widget. Before iOS 17 a Live
/// Activity could only be looked at, and ending a session meant unlocking the
/// phone you had just deliberately put down — which is the whole problem this
/// product is trying to solve, reappearing at the last step.
struct ReclaimLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReclaimActivityAttributes.self) { context in
            face(context.state)
                .activityBackgroundTint(Palette.nightCard)
                .activitySystemActionForegroundColor(Palette.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RingMark(startedAt: context.state.startedAt, size: 34)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline(context.state.memberCount))
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
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: EndSessionIntent()) {
                        Text(t("lockscreen.end"))
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .tint(Palette.edge)
                }
            } compactLeading: {
                RingMark(startedAt: context.state.startedAt, size: 16)
            } compactTrailing: {
                // Together, how many; alone, nothing. Never digits that tick.
                if context.state.memberCount > 1 {
                    Text(String(context.state.memberCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ember)
                }
            } minimal: {
                RingMark(startedAt: context.state.startedAt, size: 16)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                RingMark(startedAt: state.startedAt, size: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text(headline(state.memberCount))
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

            Button(intent: EndSessionIntent()) {
                Text(t("lockscreen.end"))
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Palette.cream)
            }
            .buttonStyle(.plain)
            .overlay { Capsule().stroke(Palette.edge, lineWidth: 1) }
        }
        .padding(20)
    }

    /// The same headline as the session screen: what you're doing when alone,
    /// the count when it's earned it.
    private func headline(_ count: Int) -> String {
        count <= 1 ? t("lockscreen.solo")
                   : t("lockscreen.together", "count", Say.count(count))
    }

    private func since(_ state: ReclaimActivityAttributes.ContentState) -> String {
        t("lockscreen.since", "place", state.placeName ?? t("docked.where.unnamed"),
          "time", Say.time(state.startedAt))
    }
}
