import SwiftUI
import ReclaimKit

/// Screen 8. NEVER show what was missed — no notification count, no messages
/// waiting. Only what was reclaimed.
struct SessionEndView: View {
    @Environment(AppState.self) private var state
    let startedAt: Date
    let minutes: Int
    let people: Int
    let place: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: Say.partOfDay(startedAt))
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 24) {
                Text(t("end.headline", "duration", Say.duration(minutes: minutes)))
                    .font(Type.display(52)).foregroundStyle(Palette.ink)
                Text(t("end.who", "count", Say.count(people),
                       "place", place ?? t("docked.where.unnamed")))
                    .font(Type.body(18)).foregroundStyle(Palette.ink2)
                HStack(spacing: 10) {
                    ForEach(0..<people, id: \.self) { _ in
                        Circle().fill(Palette.clay).frame(width: 16, height: 16)
                    }
                }
                .accessibilityHidden(true)
            }

            Spacer(minLength: 24)

            VStack(spacing: 26) {
                if let rhythmLine {
                    Text(rhythmLine)
                        .font(Type.display(22)).foregroundStyle(Palette.ink2)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 22)
                        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
                }

                PrimaryButton(title: t("end.done")) { state.justEnded = nil }
            }
        }
        .ground()
    }

    /// Evenings this week, the same count as the dot week on Home. It used to
    /// be the rhythm's run length, which isn't a week and can pass seven.
    ///
    /// Nothing at zero: under fifteen minutes doesn't qualify, so this one may
    /// not have counted — and just after ending, the reload that would count
    /// it hasn't landed. The line appears when it has; the count goes up.
    private var rhythmLine: String? {
        switch EveningCalendar.count(EveningCalendar.week(evenings: state.evenings)) {
        case 0:     nil
        case 1:     t("end.rhythm.first")
        case let n: t("end.rhythm", "count", Say.number(n))
        }
    }
}

#Preview {
    SessionEndView(startedAt: .now.addingTimeInterval(-134 * 60), minutes: 134,
                   people: 5, place: "The Kitchen Table")
        .environment(AppState(repo: PreviewRepository()))
}
