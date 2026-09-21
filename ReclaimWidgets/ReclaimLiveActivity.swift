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
            lockScreen(context.state)
                .activityBackgroundTint(Palette.nightCard)
                .activitySystemActionForegroundColor(Palette.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.placeName ?? t("docked.where.unnamed"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.cream)
                        Text(people(context.state.memberCount))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.dust)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(from: context.state.startedAt, size: 30)
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
                Brand(color: Palette.ember, size: 16)
            } compactTrailing: {
                timer(from: context.state.startedAt, size: 13)
            } minimal: {
                Brand(color: Palette.ember, size: 16)
            }
        }
    }

    private func lockScreen(_ state: ReclaimActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Brand(color: Palette.ember, size: 18)
                Text(t("lockscreen.brand")).eyebrow(Palette.dust)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.placeName ?? t("docked.where.unnamed"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.cream)
                    Text(people(state.memberCount))
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.dust)
                }
                Spacer()
                timer(from: state.startedAt, size: 40)
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

    private func people(_ count: Int) -> String {
        count <= 1 ? t("lockscreen.members.solo")
                   : t("lockscreen.members", "count", Say.count(count))
    }

    /// Counts up on its own — the system re-renders it, so the activity doesn't
    /// need updating every second.
    private func timer(from start: Date, size: CGFloat) -> some View {
        Text(timerInterval: start...Date.distantFuture, countsDown: false)
            .font(Type.display(size, weight: .light))
            .foregroundStyle(Palette.cream)
            .monospacedDigit()
            .lineLimit(1)
    }
}

/// The widget target can't see the app target, so the mark lives here too.
private struct Brand: View {
    var color: Color
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: size * 0.09).frame(width: size * 0.84)
            Circle().fill(color).frame(width: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}
