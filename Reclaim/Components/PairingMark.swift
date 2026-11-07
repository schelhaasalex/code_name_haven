import SwiftUI
import ReclaimKit

/// The scanner's one moving part. It starts as the frame the card is held to,
/// becomes the mark the moment the card is read, reaches out in slow rings
/// while the phone listens for the box, and closes — the dot filling — when
/// the box is heard. Quiet, it's the mark at rest: nothing that reads as
/// failure.
///
/// With Reduce Motion there are no rings, and every change is a crossfade.
struct PairingMark: View {
    enum Phase: Equatable { case frame, listening, paired, quiet }

    let phase: Phase
    /// The mark's size; the frame is always the card's.
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let frameSide: CGFloat = 248
    /// One ring every this many seconds, three in flight.
    private static let period = 2.4

    var body: some View {
        let framing = phase == .frame
        let side = framing ? Self.frameSide : size * 0.84
        ZStack {
            if phase == .listening && !reduceMotion { rings }
            RoundedRectangle(cornerRadius: framing ? 28 : side / 2, style: .continuous)
                .stroke(framing ? Palette.cream.opacity(0.9) : Palette.clay,
                        lineWidth: framing ? 2 : size * 0.045)
                .frame(width: side, height: side)
                .scaleEffect(phase == .paired ? 1 : (phase == .listening ? 1.04 : 1))
            Circle()
                .fill(Palette.clay)
                .frame(width: size * 0.3, height: size * 0.3)
                .scaleEffect(framing ? 0.2 : (phase == .paired ? 1 : 0.6))
                .opacity(framing ? 0 : 1)
        }
        .frame(width: framing ? Self.frameSide : size * 2.6, height: framing ? Self.frameSide : size * 2.6)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : motion, value: phase)
        .accessibilityHidden(true)
    }

    /// Closing settles with a little give; everything else eases.
    private var motion: Animation {
        phase == .paired ? .spring(response: 0.5, dampingFraction: 0.62)
                         : .spring(response: 0.6, dampingFraction: 0.9)
    }

    /// Rings drifting outward from the mark and fading as they go.
    private var rings: some View {
        TimelineView(.animation) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = (now / Self.period + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Palette.clay.opacity(0.32 * (1 - p)), lineWidth: 1.2)
                        .frame(width: size * 0.84 * (1 + p * 1.9), height: size * 0.84 * (1 + p * 1.9))
                }
            }
        }
        .transition(.opacity.animation(.easeOut(duration: 0.8)))
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            PairingMark(phase: .listening)
            PairingMark(phase: .paired)
            PairingMark(phase: .quiet)
        }
        PairingMark(phase: .frame).background(Palette.night)
    }
    .padding()
    .background(Palette.bone)
}
