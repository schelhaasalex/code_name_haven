import SwiftUI
import ReclaimKit

/// Screen 0. The first two seconds.
///
/// The ring draws itself from the top and the dot settles into the middle of
/// it — the mark is a table seen from above, so this is a table being laid.
/// It does not reuse `Brand`, deliberately: drawing-on needs `trim`, and a
/// `trim` parameter on the mark every other screen draws would put splash
/// timing into a component that has no business knowing about it. At rest the
/// two are the same shape, and that is the part worth keeping identical.
///
/// Three things make this polished rather than merely present:
///
/// 1. **It never waits.** The splash runs on its own clock and leaves on it.
///    It is an overlay, not a phase — nothing underneath is gated on it and it
///    is gated on nothing, least of all a network call (rule 7). If the load
///    finished in 200ms the splash still plays; if it hasn't finished at all,
///    the splash still leaves, onto the same bone ground it was drawn on.
/// 2. **There is no first flash.** `UILaunchScreen` is `LaunchBone`, the same
///    colour as `Palette.bone`, so the static launch image and this view's
///    first frame are the same flat paper. Nothing pops, in either system
///    appearance. `scripts/shape.sh` keeps the two colours equal.
/// 3. **Reduce Motion is a different splash, not a faster one.** Rule 4's
///    courtesy, applied to a preference someone has already stated.
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Flipped once, on appear. Every beat below keys off it at its own delay.
    @State private var run = false
    @State private var gone = false

    private var beats: SplashChoreography { .launch(reduceMotion: reduceMotion) }
    private let size: CGFloat = 96

    var body: some View {
        VStack(spacing: 26) {
            mark
            Text(t("app.name"))
                .eyebrow(Palette.muted)
                .opacity(run ? 1 : 0)
                .offset(y: run ? 0 : 6)
                .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: beats.word.duration)
                    .delay(beats.word.delay), value: run)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ground()
        .opacity(gone ? 0 : 1)
        .animation(.easeInOut(duration: beats.exit.duration), value: gone)
        // It is scenery. Whatever is underneath is already live.
        .allowsHitTesting(false)
        .task { await play() }
    }

    /// Under Reduce Motion the beats are 10ms, so the same two shapes compose
    /// instead of drawing — a still frame rather than a fast one.
    private var mark: some View {
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

    private func play() async {
        // One frame first. `task` can run before the initial render commits,
        // and a state change in that window is applied without animating —
        // which is the difference between a splash and a still image.
        try? await Task.sleep(for: .milliseconds(16))
        run = true

        try? await Task.sleep(for: .seconds(beats.exit.delay))
        gone = true

        try? await Task.sleep(for: .seconds(beats.exit.duration))
        onFinished()
    }
}

#Preview {
    SplashView {}
}
