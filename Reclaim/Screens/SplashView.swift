import SwiftUI
import ReclaimKit

/// Screen 0. The first two seconds.
///
/// Three things make this one polished rather than merely present:
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
    let variant: SplashVariant
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var run = false
    @State private var handOff = false
    @State private var gone = false

    private var beats: SplashChoreography { variant.choreography(reduceMotion: reduceMotion) }

    var body: some View {
        VStack(spacing: 26) {
            figure
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

    @ViewBuilder private var figure: some View {
        if reduceMotion {
            // Every option collapses to the same still frame: the composed
            // mark, faded up. With a 10ms figure beat, `SplashSettle` is it.
            SplashSettle(beats: beats, run: run)
        } else {
            switch variant {
            case .settle:   SplashSettle(beats: beats, run: run)
            case .faceDown: SplashFaceDown(beats: beats, run: run, handOff: handOff)
            case .lamp:     SplashLamp(beats: beats, run: run)
            }
        }
    }

    private func play() async {
        // One frame first. `task` can run before the initial render commits,
        // and a state change in that window is applied without animating —
        // which is the difference between a splash and a still image.
        try? await Task.sleep(for: .milliseconds(16))
        run = true

        try? await Task.sleep(for: .seconds(beats.core.delay))
        handOff = true

        try? await Task.sleep(for: .seconds(beats.exit.delay - beats.core.delay))
        gone = true

        try? await Task.sleep(for: .seconds(beats.exit.duration))
        onFinished()
    }
}

#Preview {
    SplashView(variant: .settle) {}
}
