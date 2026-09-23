import SwiftUI
import ReclaimKit

/// The week of dots on Home's footer, and the route to your rhythm — one of
/// only three destinations in the app. Larger on screen 8, where tonight's dot
/// fills in.
///
/// Every day is the same circle with a fill and a stroke, rather than a
/// different shape per kind, so a day changing kind animates as a colour
/// change instead of one view swapping for another.
struct DotWeek: View {
    let days: [EveningCalendar.Day]
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: size * 0.7) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Circle()
                    .fill(fill(day))
                    .overlay { Circle().strokeBorder(stroke(day), lineWidth: lineWidth(day)) }
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ day: EveningCalendar.Day) -> Color {
        switch day {
        case .docked: Palette.ink
        case .missed: Palette.line
        case .rest:   Palette.restFill
        case .future, .before: .clear
        }
    }

    private func stroke(_ day: EveningCalendar.Day) -> Color {
        switch day {
        case .rest:            Palette.restStroke
        case .future, .before: Palette.hairline
        case .docked, .missed: .clear
        }
    }

    private func lineWidth(_ day: EveningCalendar.Day) -> CGFloat {
        day == .rest ? 1.5 : 1
    }
}

#Preview {
    DotWeek(days: [.docked, .docked, .missed, .docked, .docked, .future, .future])
        .padding()
        .background(Palette.bone)
}
