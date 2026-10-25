import SwiftUI
import WidgetKit
import ReclaimKit

/// The brand's ring and dot, the ring filling over the first fifteen minutes
/// — tonight's evening becoming one that counts.
///
/// The system draws the fill on its own clock. A Live Activity can't be
/// changed at a moment in the future without the app running or a push, so a
/// progress view over a fixed interval is the one way for the lock screen to
/// show the evening start to count. It moves once, slowly, and then stops.
///
/// The widget target can't see the app target, so the mark lives here,
/// shared by the lock screen, the Dynamic Island and the wrist.
struct RingMark: View {
    let startedAt: Date
    var size: CGFloat
    /// Drawn already full, and never moving — for the wrist.
    var still = false

    private var counting: ClosedRange<Date> {
        startedAt...startedAt.addingTimeInterval(Double(EveningLanding.qualifyingMinutes * 60))
    }

    var body: some View {
        ZStack {
            if still {
                Circle()
                    .stroke(Palette.ember, lineWidth: max(2, size * 0.08))
                    .frame(width: size * 0.84, height: size * 0.84)
            } else {
                ProgressView(timerInterval: counting, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(Palette.ember)
                .frame(width: size * 0.84, height: size * 0.84)
            }
            Circle().fill(Palette.ember).frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}
