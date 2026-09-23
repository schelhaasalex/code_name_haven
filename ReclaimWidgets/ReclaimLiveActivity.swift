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

/// The brand's ring and dot, the ring filling over the first fifteen minutes
/// — tonight's evening becoming one that counts.
///
/// The system draws the fill on its own clock. A Live Activity can't be
/// changed at a moment in the future without the app running or a push, so a
/// progress view over a fixed interval is the one way for the lock screen to
/// show the evening start to count. It moves once, slowly, and then stops.
///
/// The widget target can't see the app target, so the mark lives here.
private struct RingMark: View {
    let startedAt: Date
    var size: CGFloat

    private var counting: ClosedRange<Date> {
        startedAt...startedAt.addingTimeInterval(Double(EveningLanding.qualifyingMinutes * 60))
    }

    var body: some View {
        ZStack {
            ProgressView(timerInterval: counting, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(Palette.ember)
            .frame(width: size * 0.84, height: size * 0.84)
            Circle().fill(Palette.ember).frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}
