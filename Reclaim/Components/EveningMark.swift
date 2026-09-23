import SwiftUI
import ReclaimKit

/// One dot for every evening you've had, tonight's among them. Behind the
/// session screen, where it replaced the ticking timer, and on screen 8, where
/// tonight's dot fills in.
///
/// Tonight's is the outline until it counts. The layout — rings outward from
/// your first evening at the centre — is `EveningMarkLayout`, where it can be
/// tested; this only draws it.
struct EveningMark: View {
    let layout: EveningMarkLayout
    var size: CGFloat = 104
    var dot: Color = Palette.hairline
    var tonight: Color = Palette.clay
    /// What VoiceOver says. Nil hides the mark, for where the words beside it
    /// already say it.
    var label: String?

    var body: some View {
        let points = layout.points
        let dotSize = max(3, size / 34)
        let tonightSize = dotSize * 1.7
        // Inset by tonight's dot, so the outermost ring never clips.
        let reach = size / 2 - tonightSize
        ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Group {
                    if index == points.count - 1 {
                        tonightDot.frame(width: tonightSize, height: tonightSize)
                    } else {
                        Circle().fill(dot).frame(width: dotSize, height: dotSize)
                    }
                }
                .position(x: size / 2 + point.x * reach, y: size / 2 + point.y * reach)
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
        EveningMark(layout: .init(count: 27, tonight: .waiting))
        EveningMark(layout: .init(count: 27, tonight: .counted))
        EveningMark(layout: .init(count: 1, tonight: .waiting))
    }
    .padding()
    .background(Palette.bone)
}
