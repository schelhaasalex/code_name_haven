import SwiftUI
import WidgetKit
import ReclaimKit

/// The brand's ring and dot, charging: four segments that fill as the evening
/// goes on, a light on the ring for each person who has put their phone down,
/// and a warmth that comes in at the hour (`EveningCharge`).
///
/// Nothing here moves on its own clock. A Live Activity only changes when the
/// app or a push changes it, and the phone is in the box — so the server sends
/// each step (`charge-live-activities`), and the ring changes four times in an
/// evening rather than creeping. That's what keeps it a mark and not a timer,
/// on the wrist most of all, where it's glanced at far more often than a phone
/// is picked up.
///
/// The widget target can't see the app target, so the mark lives here,
/// shared by the lock screen, the Dynamic Island and the wrist.
struct RingMark: View {
    var stage: Int
    var memberCount: Int = 1
    var size: CGFloat

    private var line: CGFloat { max(2, size * 0.09) }
    private var radius: CGFloat { size * 0.42 }
    /// A light needs room to be one. In the Dynamic Island's 16 points, the
    /// count beside the ring says it instead.
    private var lights: Int { size >= 24 ? EveningCharge.lights(memberCount: memberCount) : 0 }

    var body: some View {
        ZStack {
            ForEach(0..<EveningCharge.full, id: \.self) { segment in
                arc(segment)
                    .stroke(segment < stage ? Palette.ember : Palette.edge,
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
            }
            // Before the first segment fills: a sliver of it, so the ring
            // starts the moment the phone goes in, not fifteen minutes later.
            if stage == 0 {
                arc(0, upTo: 0.3)
                    .stroke(Palette.ember, style: StrokeStyle(lineWidth: line, lineCap: .round))
            }
            Circle().fill(Palette.ember).frame(width: size * 0.3, height: size * 0.3)
            ForEach(Array(EveningCharge.lightAngles(lights).enumerated()), id: \.offset) { _, angle in
                Circle()
                    .fill(Palette.cream)
                    .frame(width: line * 1.6, height: line * 1.6)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.ember.opacity(glow), radius: size * 0.25)
    }

    /// The warmth: none until the hour, then some, then full at the peak.
    private var glow: Double {
        switch stage {
        case EveningCharge.full...: 0.55
        case EveningCharge.full - 1: 0.25
        default: 0
        }
    }

    /// One quarter of the ring, clockwise from the top, with a gap either side.
    private func arc(_ segment: Int, upTo fraction: Double = 1) -> Path {
        let gap = 16.0
        let start = -90 + Double(segment) * 90 + gap / 2
        let end = start + (90 - gap) * fraction
        return Path { p in
            p.addArc(center: CGPoint(x: size / 2, y: size / 2), radius: radius,
                     startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        }
    }
}

#Preview("The evening charges") {
    HStack(spacing: 20) {
        RingMark(stage: 0, size: 44)
        RingMark(stage: 1, size: 44)
        RingMark(stage: 2, memberCount: 2, size: 44)
        RingMark(stage: 3, memberCount: 3, size: 44)
        RingMark(stage: 4, memberCount: 3, size: 44)
    }
    .padding(30)
    .background(Palette.nightCard)
}
