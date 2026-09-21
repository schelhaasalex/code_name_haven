import SwiftUI
import ReclaimKit

/// Option C's figure. The mark is already there, faintly, and a light comes up
/// over it — a lamp switched on above a table that was set before you walked in.
///
/// The least motion of the three and the shortest. Nothing travels and nothing
/// rotates; the only things that change are light and colour, which is what a
/// good appliance does when you turn it on.
struct SplashLamp: View {
    let beats: SplashChoreography
    /// Flipped once, on appear.
    let run: Bool
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            bloom
            mark
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Warm paper over the bone ground, with the faintest clay in it. Sized
    /// well past the screen so it reads as light in the room rather than as a
    /// circle drawn on a screen.
    private var bloom: some View {
        ZStack {
            RadialGradient(colors: [Palette.paper, Palette.paper.opacity(0)],
                           center: .center, startRadius: 0, endRadius: size * 2.5)
            RadialGradient(colors: [Palette.clay.opacity(0.09), Palette.clay.opacity(0)],
                           center: .center, startRadius: 0, endRadius: size * 1.9)
        }
        .frame(width: size * 5.2, height: size * 5.2)
        .scaleEffect(run ? 1 : 0.42)
        .opacity(run ? 1 : 0)
        .animation(.timingCurve(0.16, 0.8, 0.28, 1, duration: beats.figure.duration)
            .delay(beats.figure.delay), value: run)
    }

    /// Present from the first frame, barely, so there is nothing to cut to —
    /// the light finds something that was already on the table.
    ///
    /// Only brightness changes. Clay at 16% on bone already reads as the
    /// hairline, so animating the colour as well was a second way of saying the
    /// same thing — and one the prototype could not have matched.
    private var mark: some View {
        ZStack {
            Circle()
                .stroke(Palette.clay, lineWidth: size * 0.068)
                .frame(width: size * 0.84)
            Circle()
                .fill(Palette.clay)
                .frame(width: size * 0.3)
        }
        .opacity(run ? 1 : 0.16)
        .animation(.easeOut(duration: beats.core.duration).delay(beats.core.delay), value: run)
    }
}

#Preview {
    VStack(spacing: 120) {
        SplashLamp(beats: .lamp, run: false)
        SplashLamp(beats: .lamp, run: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bone)
}
