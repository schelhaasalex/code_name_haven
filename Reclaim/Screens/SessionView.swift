import SwiftUI
import ReclaimKit

/// Screens 6 and 12. In session — with five people, or with one.
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
/// The only thing that moves is tonight's dot, once, at fifteen minutes.
struct SessionView: View {
    @Environment(AppState.self) private var state

    private var solo: Bool { state.members.count <= 1 }

    /// Today already counted, earlier: tonight's dot is that one, filled from
    /// the start.
    private var alreadyCounted: Bool {
        state.session.map { state.evenings.contains($0.localDate) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: state.placeName ?? t("box.unnamed"),
                    mark: Palette.ember, tint: Palette.dust)

            Spacer(minLength: 20)

            // Alone, the headline is what you did, never a count: "Just you."
            // at hero size made being alone the news. Together, the count has
            // earned it.
            VStack(alignment: .leading, spacing: 20) {
                Text(solo ? t("session.line.solo")
                          : t("session.together", "count", Say.count(state.members.count)))
                    .font(Type.display(52, weight: .light))
                    .foregroundStyle(Palette.cream)
                    .lineSpacing(2)
                    .contentTransition(.opacity)
                Text(t("session.since", "time", Say.time(state.startedAt ?? .now)))
                    .font(Type.body(16)).foregroundStyle(Palette.dim)
            }
            .animation(.easeInOut(duration: 0.5), value: state.members.count)

            Spacer(minLength: 28)

            Text(t("session.out"))
                .font(Type.note).foregroundStyle(Palette.dim).lineSpacing(2)
        }
        .ground(night: true)
        .background { mark }
    }

    /// Your evenings, behind everything. Looked at once a minute, so tonight's
    /// dot fills within a minute of fifteen — nothing on this screen changes
    /// more often than that.
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
                EveningMark(layout: layout, size: 340, dot: Palette.edge, tonight: Palette.ember,
                            label: markLabel(layout.count))
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: layout)
            }
            .offset(x: 10, y: 70)
            .allowsHitTesting(false)
        }
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
        members: [Member(profileId: PreviewRepository.me, displayName: "Alex", stillLive: true)])))
}
