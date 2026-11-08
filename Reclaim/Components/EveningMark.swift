import SwiftUI
import ReclaimKit

/// One dot for every evening you've had, tonight's among them. Behind the
/// session screen, where it replaced the ticking timer, and on screen 8, where
/// tonight's dot fills in.
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
    /// Whose sky: `EveningMarkLayout.seed(_:)` of the account.
    var seed: UInt64 = 0
    /// What VoiceOver says. Nil hides the mark, for where the words beside it
    /// already say it.
    var label: String?

    var body: some View {
        let stars = layout.stars(seed: seed)
        let tonightSize = max(3, size / 34) * 1.7
        // Inset by tonight's star, so the outermost never clips.
        let reach = size / 2 - tonightSize
        // Smaller as the sky fills, so stars never touch.
        let starSize = max(1.5, min(size / 34, reach * 1.5 / Double(stars.count).squareRoot()))
        ZStack {
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
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
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
        EveningMark(layout: .init(count: 7, tonight: .waiting), seed: 42)
        EveningMark(layout: .init(count: 27, tonight: .counted), recent: 3, seed: 42)
        EveningMark(layout: .init(count: 90, tonight: .counted), seed: 42)
    }
    .padding()
    .background(Palette.bone)
}
