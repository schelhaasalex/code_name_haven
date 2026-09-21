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

#Preview {
    DotWeek(days: [.docked, .docked, .missed, .docked, .docked, .future, .future])
        .padding()
        .background(Palette.bone)
}
