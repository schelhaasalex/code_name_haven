import SwiftUI
import ReclaimKit

/// The week of dots on Home's footer, and the route to your rhythm — one of
/// only three destinations in the app.
struct DotWeek: View {
    let days: [EveningCalendar.Day]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                dot(day).frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func dot(_ day: EveningCalendar.Day) -> some View {
        switch day {
        case .docked: Circle().fill(Palette.ink)
        case .missed: Circle().fill(Palette.line)
        case .rest:   Circle().fill(Palette.restFill).overlay { Circle().stroke(Palette.restStroke, lineWidth: 1.5) }
        case .future: Circle().stroke(Palette.hairline, lineWidth: 1)
        }
    }
}

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
    VStack(spacing: 24) {
        DotWeek(days: [.docked, .docked, .missed, .docked, .docked, .future, .future])
        DayGrid(days: EveningCalendar.grid(evenings: [], weeks: 2))
    }
    .padding()
}
