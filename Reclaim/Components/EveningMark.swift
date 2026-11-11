import SwiftUI
import ReclaimKit

/// One dot for every evening you've had, tonight's among them: Home's sky
/// (screen 2), above the words on the session screen (6), where it replaced
/// the ticking timer, and on screen 8, where tonight's dot fills in.
///
/// Tonight's is the outline until it counts. The sky — your first evening at
/// the centre, each one after landing further out, in places your account
/// decides and nothing moves — is `EveningMarkLayout`, where it can be tested;
/// this only draws it.
struct EveningMark: View {
    let layout: EveningMarkLayout
    var size: CGFloat = 104
    var dot: Color = Palette.hairline
    var tonight: Color = Palette.clay
    /// The few stars with a colour: the first for tint 1, the second for 2.
    var tints: [Color] = [Palette.starGold, Palette.starBlue]
    /// How many of the stars just before tonight's are this week's — drawn
    /// in `near`, so the week is in the sky rather than in a row beside it.
    var recent: Int = 0
    var near: Color = Palette.ink2
    /// A ring that breathes out from tonight's star while it waits — the one
    /// thing on Home that asks anything. Still once tonight has counted.
    var pulse = false
    /// Tapping tonight's star. Nil, and it isn't something to tap.
    var onTonight: (() -> Void)?
    /// Whose sky: `EveningMarkLayout.seed(_:)` of the account.
    var seed: UInt64 = 0
    /// What VoiceOver says. Nil hides the mark, for where the words beside it
    /// already say it.
    var label: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let stars = layout.stars(seed: seed)
        let tonightSize = max(3, size / 34) * 1.7
        // Inset by tonight's star, so the outermost never clips.
        let reach = size / 2 - tonightSize
        // Smaller as the sky fills, so stars never touch.
        let starSize = max(1.5, min(size / 34, reach * 1.5 / Double(stars.count).squareRoot()))
        ZStack {
            if let last = stars.last, pulse, layout.tonight == .waiting {
                ring(tonightSize)
                    .position(x: size / 2 + last.x * reach, y: size / 2 + last.y * reach)
            }
            ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                Group {
                    if index == stars.count - 1 {
                        tonightDot.frame(width: tonightSize, height: tonightSize)
                    } else if index >= stars.count - 1 - recent {
                        Circle().fill(near)
                            .frame(width: starSize * star.size * 1.15, height: starSize * star.size * 1.15)
                    } else {
                        Circle().fill(star.tint > 0 && tints.count >= star.tint ? tints[star.tint - 1] : dot)
                            .opacity(star.brightness)
                            .frame(width: starSize * star.size, height: starSize * star.size)
                    }
                }
                .position(x: size / 2 + star.x * reach, y: size / 2 + star.y * reach)
            }
            if let last = stars.last, let onTonight {
                // A star is a few points across; a finger is 44.
                Button(action: onTonight) { Circle().fill(.clear).contentShape(Circle()) }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .position(x: size / 2 + last.x * reach, y: size / 2 + last.y * reach)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }

    /// Drawn past the sky's frame on purpose: tonight's star is often at
    /// the edge, and a ring cut off there reads as a mistake.
    @ViewBuilder private func ring(_ star: CGFloat) -> some View {
        let circle = Circle().stroke(tonight, lineWidth: 1.2).frame(width: star * 1.6, height: star * 1.6)
        if reduceMotion {
            circle.scaleEffect(1.5).opacity(0.3)
        } else {
            circle.phaseAnimator([false, true]) { ring, out in
                ring.scaleEffect(out ? 2.3 : 0.6).opacity(out ? 0 : 0.6)
            } animation: { out in
                out ? .easeOut(duration: 2.8) : nil
            }
        }
    }

    private var tonightDot: some View {
        Circle()
            .fill(layout.tonight == .counted ? tonight : .clear)
            .overlay { Circle().strokeBorder(tonight, lineWidth: 1.5) }
            .scaleEffect(layout.tonight == .counted ? 1 : 0.85)
    }
}

#Preview {
    HStack(spacing: 24) {
        EveningMark(layout: .init(count: 7, tonight: .waiting), pulse: true, seed: 42)
        EveningMark(layout: .init(count: 27, tonight: .counted), recent: 3, seed: 42)
        EveningMark(layout: .init(count: 90, tonight: .counted), seed: 42)
    }
    .padding()
    .background(Palette.bone)
}
