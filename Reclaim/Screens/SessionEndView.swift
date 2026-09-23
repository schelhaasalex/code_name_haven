import SwiftUI
import ReclaimKit

/// Screen 8. NEVER show what was missed — no notification count, no messages
/// waiting. Only what was reclaimed.
///
/// It arrives in beats rather than all at once: the time counts up to what was
/// credited, the people who were there appear one by one, and tonight's dot
/// fills in on your week. Drawn complete, it read as a receipt; the reward is
/// watching the evening land. Reduce Motion skips straight to the end.
struct SessionEndView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ended: AppState.Ended

    /// The notification question, asked here — after an evening, when the
    /// nudge has something to be for — and never at first launch.
    @State private var offeringNudge = false
    @State private var shownMinutes = 0
    @State private var shownPeople = 0
    @State private var dotLanded = false
    @State private var lineShown = false

    private var landing: EveningLanding { ended.landing }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: Say.partOfDay(ended.startedAt))
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 24) {
                Text(t("end.headline", "duration", Say.duration(minutes: shownMinutes)))
                    .font(Type.display(52)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(shownMinutes)))
                    // VoiceOver hears the credited time, not a number mid-count.
                    .accessibilityLabel(t("end.headline", "duration", Say.duration(minutes: ended.minutes)))
                Text(t("end.who", "count", Say.count(ended.people),
                       "place", ended.place ?? t("docked.where.unnamed")))
                    .font(Type.body(18)).foregroundStyle(Palette.ink2)
                // Every slot laid out from the start, so nothing shifts as
                // they appear. They are all people who were there.
                HStack(spacing: 10) {
                    ForEach(0..<ended.people, id: \.self) { i in
                        Circle().fill(Palette.clay).frame(width: 16, height: 16)
                            .scaleEffect(i < shownPeople ? 1 : 0.3)
                            .opacity(i < shownPeople ? 1 : 0)
                    }
                }
                .accessibilityHidden(true)
                // Under fifteen minutes it's kept, not counted — say so once,
                // plainly, rather than leaving the rhythm line to go quiet.
                if !landing.qualifies {
                    Text(t("end.short")).font(Type.note).foregroundStyle(Palette.muted)
                }
            }

            Spacer(minLength: 24)

            VStack(spacing: 26) {
                if let rhythmLine {
                    VStack(alignment: .leading, spacing: 16) {
                        DotWeek(days: EveningCalendar.week(
                                    evenings: dotLanded ? landing.after : landing.before),
                                size: 16)
                        Text(rhythmLine)
                            .font(Type.display(22)).foregroundStyle(Palette.ink2)
                            .lineSpacing(3)
                            .opacity(lineShown ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 22)
                    .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
                }

                if offeringNudge { nudgeOffer }

                PrimaryButton(title: t("end.done")) { state.justEnded = nil }
            }
        }
        .ground()
        .task { await land() }
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

    /// The beats. Each step is a state change inside an animation, so what
    /// moves is the difference between two true pictures — the week before
    /// tonight, and the week with it.
    private func land() async {
        guard !reduceMotion else {
            shownMinutes = ended.minutes; shownPeople = ended.people
            dotLanded = true; lineShown = true
            return
        }
        guard await pause(EveningLanding.settle) else { return }

        let counts = EveningLanding.counts(to: ended.minutes)
        let step = EveningLanding.counting / Double(counts.count)
        for n in counts {
            withAnimation(.snappy(duration: step)) { shownMinutes = n }
            guard await pause(step) else { return }
        }

        for n in 1...max(1, ended.people) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { shownPeople = n }
            guard await pause(EveningLanding.perPerson) else { return }
        }

        guard await pause(EveningLanding.beforeDot) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { dotLanded = true }
        if landing.tonight != nil { Sensation.landed() }

        guard await pause(EveningLanding.beforeLine) else { return }
        withAnimation(.easeOut(duration: 0.6)) { lineShown = true }
    }

    /// False once the screen has gone, so a dismissed screen stops mid-beat.
    private func pause(_ seconds: Double) async -> Bool {
        (try? await Task.sleep(for: .seconds(seconds))) != nil
    }

    /// Evenings this week, the same count as the dot week on Home. It used to
    /// be the rhythm's run length, which isn't a week and can pass seven.
    ///
    /// Counted from the week WITH tonight in it, known at the moment of
    /// ending — not from `state.evenings`, whose reload hadn't landed yet, so
    /// this line used to be missing on exactly the evening it was for.
    private var rhythmLine: String? {
        // A short one didn't count, and a line about this week's evenings
        // right under it reads as though it did.
        guard landing.qualifies else { return nil }
        return switch EveningCalendar.count(EveningCalendar.week(evenings: landing.after)) {
        case 0:     nil
        case 1:     t("end.rhythm.first")
        case let n: t("end.rhythm", "count", Say.number(n))
        }
    }
}

#Preview("First this week") {
    SessionEndView(ended: .init(startedAt: .now.addingTimeInterval(-134 * 60), minutes: 134,
                                people: 5, place: "The Kitchen Table",
                                landing: EveningLanding(known: [], localDate: today, minutes: 134)))
        .environment(AppState(repo: PreviewRepository()))
}

#Preview("Short") {
    SessionEndView(ended: .init(startedAt: .now.addingTimeInterval(-9 * 60), minutes: 9,
                                people: 1, place: nil,
                                landing: EveningLanding(known: [], localDate: today, minutes: 9)))
        .environment(AppState(repo: PreviewRepository()))
}

private let today: String = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: .now)
}()
