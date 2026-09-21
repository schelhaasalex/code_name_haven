import SwiftUI
import ReclaimKit

/// Option A's figure. The ring draws itself, then the dot settles into the
/// middle of it. The mark is a table seen from above, so this is a table being
/// laid — which is the gesture the whole product is about.
///
/// It does not reuse `Brand`, deliberately: drawing-on needs `trim`, and a
/// `trim` parameter on the mark every other screen draws would put splash
/// timing into a component that has no business knowing about it. At rest the
/// two are the same shape, and that is the part worth keeping identical.
struct SplashSettle: View {
    let beats: SplashChoreography
    /// Flipped once, on appear. Every beat below keys off it at its own delay.
    let run: Bool
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: run ? 1 : 0)
                .stroke(Palette.clay,
                        style: StrokeStyle(lineWidth: size * 0.068, lineCap: .round))
                .frame(width: size * 0.84)
                // Trim starts at 3 o'clock; a table is laid from the top.
                .rotationEffect(.degrees(-90))
                .animation(.timingCurve(0.22, 0.61, 0.36, 1, duration: beats.figure.duration)
                    .delay(beats.figure.delay), value: run)

            Circle()
                .fill(Palette.clay)
                .frame(width: size * 0.3)
                .scaleEffect(run ? 1 : 0.2)
                .opacity(run ? 1 : 0)
                // High damping on purpose. A dot that bounces is a different
                // brand — this one arrives and stays put.
                .animation(.spring(response: beats.core.duration, dampingFraction: 0.86)
                    .delay(beats.core.delay), value: run)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    // The resting frame. Motion is reviewed in `prototype/splash.html`, which
    // runs the same four beats — a preview can't be scrubbed.
    VStack(spacing: 40) {
        SplashSettle(beats: .settle, run: true)
        SplashSettle(beats: .settle, run: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bone)
}
