import SwiftUI
import ReclaimKit

/// The four-week grid on screen 10.
struct DayGrid: View {
    let days: [EveningCalendar.Day]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 7),
                  spacing: 9) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                RoundedRectangle(cornerRadius: 9)
                    .fill(fill(day))
                    .frame(height: 32)
                    .overlay { stroke(day) }
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ day: EveningCalendar.Day) -> Color {
        switch day {
        case .docked: Palette.ink
        case .missed: Palette.line
        case .rest:   Palette.restFill
        case .future: .clear
        }
    }

    @ViewBuilder private func stroke(_ day: EveningCalendar.Day) -> some View {
        switch day {
        case .rest:
            RoundedRectangle(cornerRadius: 9).stroke(Palette.restStroke, lineWidth: 1.5)
        case .future:
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        default:
            EmptyView()
        }
    }
}

#Preview {
    DayGrid(days: EveningCalendar.grid(evenings: [], weeks: 2))
        .padding()
        .background(Palette.bone)
}
