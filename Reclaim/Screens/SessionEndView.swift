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

    /// The notification question, asked here — after an evening, when the
    /// nudge has something to be for — and never at first launch.
    @State private var offeringNudge = false

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
                // Under fifteen minutes it's kept, not counted — say so once,
                // plainly, rather than leaving the rhythm line to go quiet.
                if minutes < 15 {
                    Text(t("end.short")).font(Type.note).foregroundStyle(Palette.muted)
                }
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

                if offeringNudge { nudgeOffer }

                PrimaryButton(title: t("end.done")) { state.justEnded = nil }
            }
        }
        .ground()
        .task {
            let unasked = await Notifications.canOffer()
            offeringNudge = unasked && state.profile?.nudgeEnabled == true
        }
    }

    /// Yes asks the system; no turns the nudge off, so it's never offered again.
    /// Either way it can be changed in Settings.
    private var nudgeOffer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("end.nudge.title")).font(Type.body(16, weight: .medium)).foregroundStyle(Palette.ink)
            Text(t("end.nudge.body", "time", Say.hour(state.profile?.nudgeHour ?? 19)))
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
            HStack(spacing: 20) {
                TextAction(title: t("end.nudge.yes"), tint: Palette.ink) { answerNudge(true) }
                    .fixedSize()
                TextAction(title: t("end.nudge.no")) { answerNudge(false) }
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    private func answerNudge(_ yes: Bool) {
        offeringNudge = false
        Task { await state.setNudge(on: yes) }
    }

    /// Evenings this week, the same count as the dot week on Home. It used to
    /// be the rhythm's run length, which isn't a week and can pass seven.
    ///
    /// Nothing at zero: under fifteen minutes doesn't qualify, so this one may
    /// not have counted — and just after ending, the reload that would count
    /// it hasn't landed. The line appears when it has; the count goes up.
    private var rhythmLine: String? {
        // A short one didn't count, and a line about this week's evenings
        // right under it reads as though it did.
        guard minutes >= 15 else { return nil }
        return switch EveningCalendar.count(EveningCalendar.week(evenings: state.evenings)) {
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
