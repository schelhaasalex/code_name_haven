import SwiftUI
import ReclaimKit

/// Screen 6. In the box — with five people, or with one.
///
/// Rarely seen: the phone is in the box, and a phone in a hand that isn't
/// charging has left it, so opening the app mostly ends the evening and shows
/// its receipt. This is for a drawer pulled open to look. There is no End:
/// the box is the only switch.
///
/// Solo is deliberately the SAME view rather than a degraded variant: the
/// parallel construction is the statement. Most evenings are alone, even for
/// the most social person, so alone has to be whole on its own.
///
/// NOTHING HERE TICKS. It used to be a 92pt timer counting seconds, which made
/// the one screen you're meant to put down reward checking, and framed the
/// evening as a performance. Time is a receipt, not an instrument: this says
/// when you started, a fact that doesn't change, and screen 8 says how long.
/// Nothing here changes more than once a minute — the headline at the ring's
/// steps, tonight's dot at fifteen minutes — but the countdown once the phone
/// is out.
struct SessionView: View {
    @Environment(AppState.self) private var state

    private var solo: Bool { state.memberCount <= 1 }

    /// Today already counted, earlier: tonight's dot is that one, filled from
    /// the start.
    private var alreadyCounted: Bool {
        state.session.map { state.evenings.contains($0.localDate) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The box, or — when the app can't say which — when it was.
            Eyebrow(text: state.placeName ?? Say.partOfDay(state.startedAt ?? .now),
                    mark: Palette.ember, tint: Palette.dust)

            Spacer(minLength: 12)
            // The sky in the space above the words, never behind them.
            mark.frame(maxWidth: .infinity)
            Spacer(minLength: 20)

            // The headline is where the evening has got to, alone or not:
            // "Just you." at hero size made being alone the news, and a count
            // in its place meant a group never saw "Today counts." Who's
            // there goes in the line under it. It changes at the ring's
            // steps, not every minute.
            VStack(alignment: .leading, spacing: 20) {
                if let until = state.leavingUntil {
                    // Out of the box: when it ends, and that putting it back
                    // carries on. The only seconds on this screen that tick.
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t("leaving.headline"))
                        Text(timerInterval: min(Date.now, until)...until, countsDown: true)
                            .monospacedDigit()
                    }
                    .font(Type.display(52, weight: .light))
                    .foregroundStyle(Palette.cream)
                    Text(t("leaving.body"))
                        .font(Type.body(16)).foregroundStyle(Palette.dim)
                } else {
                    TimelineView(.everyMinute) { context in
                        Text(EveningCharge.line(minutes: state.startedAt.map {
                                 context.date.timeIntervalSince($0) / 60 }))
                            .font(Type.display(52, weight: .light))
                            .foregroundStyle(Palette.cream)
                            .lineSpacing(2)
                            .contentTransition(.opacity)
                    }
                    Text(sinceLine)
                        .contentTransition(.opacity)
                        .font(Type.body(16)).foregroundStyle(Palette.dim)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: state.memberCount)
            .animation(.easeInOut(duration: 0.3), value: state.leavingUntil)

            Spacer(minLength: 28)

            // While counting down it's already out; the line would argue.
            Text(t("session.out"))
                .font(Type.note).foregroundStyle(Palette.dim).lineSpacing(2)
                .opacity(state.leavingUntil == nil ? 1 : 0)
        }
        .ground(night: true)
        // Out of the box with the app open in a hand: one tap as the
        // countdown starts, so it's felt before it's read. Nothing when it's
        // put back. iOS plays haptics only for the app on screen, so a phone
        // taken out locked has the lock screen's countdown and no tap.
        .sensoryFeedback(.impact(weight: .medium), trigger: state.leavingUntil) { old, new in
            old == nil && new != nil
        }
    }

    /// Your evenings, above the words. Looked at once a minute, so tonight's
    /// star fills within a minute of fifteen — nothing on this screen changes
    /// more often than that. It sat behind the screen once, under the night's
    /// own colour, and nobody ever saw it.
    @ViewBuilder private var mark: some View {
        // Nothing, rather than one dot, when the database hasn't said how many
        // evenings there are: a single dot behind the screen is a sentence,
        // and it would be the wrong one.
        if let total = state.eveningTotal {
            TimelineView(.everyMinute) { context in
                let layout = EveningMarkLayout.during(
                    total: total.count,
                    alreadyCounted: alreadyCounted,
                    elapsed: context.date.timeIntervalSince(state.startedAt ?? context.date))
                EveningMark(layout: layout, size: 250, dot: Palette.edge, tonight: Palette.ember,
                            tints: [Palette.starGold.opacity(0.6), Palette.starBlue.opacity(0.7)],
                            seed: state.skySeed, label: markLabel(layout.count))
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: layout)
            }
            .allowsHitTesting(false)
        }
    }

    /// "Since 7:27" alone; "Three of you · since 7:27" together.
    private var sinceLine: String {
        let time = Say.time(state.startedAt ?? .now)
        return solo ? t("session.since", "time", time)
                    : t("evening.together", "count", Say.count(state.memberCount), "time", time)
    }

    /// "One evenings" was what VoiceOver read on a first evening.
    private func markLabel(_ count: Int) -> String {
        count == 1 ? t("session.a11y.mark.one")
                   : t("session.a11y.mark", "count", Say.number(count))
    }
}

#Preview("Together") {
    SessionView().environment(AppState(repo: PreviewRepository()))
}

#Preview("Just you") {
    SessionView().environment(AppState(repo: PreviewRepository(
        members: 1)))
}
