import SwiftUI
import ReclaimKit

/// Screen 8. NEVER show what was missed — no notification count, no messages
/// waiting. Only what was reclaimed.
///
/// The time arrives here as a receipt — when it started, when it ended, how
/// long, in words — because the session screen no longer counts it. Below it,
/// your evenings, with tonight's dot filling in among them. Alone or with five
/// people it's the same screen: most evenings are alone, and an evening alone
/// is the same thing, smaller.
struct SessionEndView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ended: AppState.Ended

    @State private var landed = false

    private var landing: EveningLanding { ended.landing }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: Say.partOfDay(ended.startedAt))
            Spacer(minLength: 24)
            receipt
            Spacer(minLength: 24)
            VStack(spacing: 22) {
                evenings
                // Done, and under a day that counted, once, the question.
                PrimaryButton(title: t("end.done")) { state.doneWithReceipt() }
            }
        }
        .ground()
        .task { await land() }
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("end.span", "from", Say.time(ended.startedAt), "to", Say.time(ended.endedAt)))
                .font(Type.body(16)).foregroundStyle(Palette.muted)
            Text(receiptLine)
                .font(Type.display(44)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            // Which box, when the app knows; nothing rather than a name for
            // a box that doesn't exist.
            if let place = ended.place {
                Text(t("end.where", "place", place))
                    .font(Type.body(17)).foregroundStyle(Palette.ink2)
            }
            // Together, the line above is everyone's; what it was for is
            // only yours, said as what you said.
            if ended.people > 1, let reason = state.reason {
                Text(t("end.reason", "why", reason.label))
                    .font(Type.body(15)).foregroundStyle(Palette.muted)
            }
        }
    }

    /// Your evenings. The mark on the left fills tonight's dot; the words on
    /// the right move up by one as it does.
    private var evenings: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only when the database has told us how many. Unasked, the line
            // below is still true — tonight's is the newest, and they don't
            // go away — and it claims no number.
            if landing.known {
                HStack(spacing: 18) {
                    EveningMark(layout: landed ? landing.after : landing.before, seed: state.skySeed)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("end.evenings.label")).eyebrow(Palette.muted)
                        Text(countLine)
                            .font(Type.display(22)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.numericText())
                    }
                }
            }
            Text(bodyLine)
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    /// "An hour and a half, all yours.", "An hour and a half back, for the
    /// kids." — or "…, the three of you."
    private var receiptLine: String {
        let duration = Say.spokenDuration(minutes: ended.minutes)
        if ended.people > 1 {
            return t("end.receipt", "duration", duration, "count", Say.number(ended.people))
        }
        return state.reason.map { t("end.receipt.reason", "duration", duration, "for", $0.purpose) }
            ?? t("end.receipt.solo", "duration", duration)
    }

    private var countLine: String {
        let n = landed ? landing.evenings : landing.total
        let month = Say.month(from: landing.since) ?? ""
        switch n {
        case 0:                               return t("end.evenings.none")
        case 1 where landed && landing.lands: return t("end.evenings.first")
        case 1:                               return t("end.evenings.one", "month", month)
        default:                              return t("end.evenings", "count", Say.number(n), "month", month)
        }
    }

    /// Under fifteen minutes it's kept, not counted — said once, plainly.
    private var bodyLine: String {
        if !landing.qualifies { return t("end.short") }
        return landing.alreadyCounted ? t("end.evenings.again") : t("end.evenings.body")
    }

    /// A breath, then tonight's dot fills. Reduce Motion starts it filled.
    private func land() async {
        guard !reduceMotion else { landed = true; return }
        guard (try? await Task.sleep(for: .seconds(EveningLanding.pause))) != nil else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { landed = true }
    }
}

#Preview("Alone") {
    SessionEndView(ended: .sample(minutes: 90, people: 1, place: nil))
        .environment(AppState(repo: PreviewRepository()))
}

#Preview("Together, at a place") {
    SessionEndView(ended: .sample(minutes: 134, people: 3, place: "The Kitchen Table",
                                  placeId: PreviewRepository.kitchenTable))
        .environment(AppState(repo: PreviewRepository()))
}

#Preview("Too short to count") {
    SessionEndView(ended: .sample(minutes: 9, people: 1, place: nil))
        .environment(AppState(repo: PreviewRepository()))
}

/// The database never answered. The evening is still an evening; the app just
/// doesn't say how many there have been.
#Preview("Evenings unknown") {
    SessionEndView(ended: .sample(minutes: 90, people: 1, place: nil, total: nil))
        .environment(AppState(repo: PreviewRepository()))
}

private extension AppState.Ended {
    static func sample(minutes: Int, people: Int, place: String?, placeId: UUID? = nil,
                       total: EveningTotal? = EveningTotal(count: 26, first: "2026-06-03")) -> Self {
        let now = Date()
        return .init(startedAt: now.addingTimeInterval(-Double(minutes) * 60), endedAt: now,
                     minutes: minutes, people: people, place: place, placeId: placeId,
                     landing: EveningLanding(total: total, known: [],
                                             localDate: PlainDate.string(from: now),
                                             minutes: minutes))
    }
}
