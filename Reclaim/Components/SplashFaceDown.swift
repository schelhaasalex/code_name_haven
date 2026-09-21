import SwiftUI
import ReclaimKit

/// Option B's figure. A phone stands, turns over, settles with weight — and the
/// ring of the mark spreads out from where it landed.
///
/// It is the only one of the three that says anything: the gesture makes the
/// table. That earns it the extra half-second it costs, or it doesn't, which is
/// the thing to decide while watching it.
///
/// Two flags rather than one, because the phone has to arrive and then give
/// way, and a single boolean cannot fade something in and back out again.
struct SplashFaceDown: View {
    let beats: SplashChoreography
    /// The phone arrives and turns over.
    let run: Bool
    /// The phone gives way to the mark. Flipped when the core beat begins.
    let handOff: Bool
    var size: CGFloat = 96

    private var slabWidth: CGFloat { size * 0.58 }
    private var slabHeight: CGFloat { slabWidth * 54 / 38 }   // PhoneSlab's proportions

    var body: some View {
        ZStack {
            phone
            ring
            dot
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The slab, and the shadow it casts coming down. The shadow is what gives
    /// it weight — without one the turn reads as a card flipping.
    ///
    /// Three stacked animations, innermost first: the turn, the arrival, the
    /// departure. The sub-beat numbers are fractions of a named beat rather
    /// than durations of their own, so retiming the option still only means
    /// editing `SplashChoreography`.
    private var phone: some View {
        ZStack {
            Ellipse()
                .fill(Palette.ink.opacity(run ? 0.15 : 0.04))
                .frame(width: slabWidth * (run ? 1.18 : 0.7), height: slabWidth * 0.22)
                .blur(radius: run ? 9 : 4)
                .offset(y: slabHeight * 0.62)

            RoundedRectangle(cornerRadius: slabWidth * 0.24, style: .continuous)
                .fill(Palette.ink)
                .frame(width: slabWidth, height: slabHeight)
                .rotationEffect(.degrees(run ? 180 : 0))
                .scaleEffect(y: run ? 0.86 : 1)
        }
        // The turn takes the back two thirds of the figure beat. The front
        // third is the phone simply being there, upright, before anything
        // happens to it — which is the whole reason the turn reads as a choice.
        .animation(.timingCurve(0.34, 0.02, 0.16, 1, duration: beats.figure.duration * 0.66)
            .delay(beats.figure.delay + beats.figure.duration * 0.34), value: run)
        .opacity(run ? 1 : 0)
        .animation(.easeOut(duration: beats.figure.duration * 0.3)
            .delay(beats.figure.delay), value: run)
        .opacity(handOff ? 0 : 1)
        .animation(.easeInOut(duration: beats.core.duration * 0.6), value: handOff)
    }

    /// Grows out of the slab's footprint, so the mark is made by the gesture
    /// rather than cut to.
    private var ring: some View {
        Circle()
            .stroke(Palette.clay, lineWidth: size * 0.068)
            .frame(width: size * 0.84)
            .scaleEffect(handOff ? 1 : slabWidth / (size * 0.84))
            .opacity(handOff ? 1 : 0)
            .animation(.timingCurve(0.2, 0.7, 0.24, 1, duration: beats.core.duration),
                       value: handOff)
    }

    private var dot: some View {
        Circle()
            .fill(Palette.clay)
            .frame(width: size * 0.3)
            .scaleEffect(handOff ? 1 : 0.3)
            .opacity(handOff ? 1 : 0)
            .animation(.spring(response: beats.core.duration * 0.7, dampingFraction: 0.88)
                .delay(beats.core.duration * 0.45), value: handOff)
    }
}

#Preview {
    // The three resting frames the beats move between. Motion is reviewed in
    // `prototype/splash.html`, which runs the same timings.
    VStack(spacing: 44) {
        SplashFaceDown(beats: .faceDown, run: false, handOff: false)
        SplashFaceDown(beats: .faceDown, run: true, handOff: false)
        SplashFaceDown(beats: .faceDown, run: true, handOff: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bone)
}
