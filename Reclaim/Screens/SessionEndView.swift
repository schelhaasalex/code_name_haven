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

    /// The notification question, asked here — after an evening, when the
    /// nudge has something to be for — and never at first launch.
    @State private var offeringNudge = false
    @State private var landed = false
    /// The place's own total, from `place_summary`. Until it arrives — or if
    /// it never does — the line just names the place. Nothing waits on it.
    @State private var placeEvenings: Int?

    private var landing: EveningLanding { ended.landing }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: Say.partOfDay(ended.startedAt))
            Spacer(minLength: 24)
            receipt
            Spacer(minLength: 24)
            VStack(spacing: 22) {
                evenings
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
        .task {
            guard let id = ended.placeId else { return }
            placeEvenings = try? await state.repo.summary(of: id).evenings
        }
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("end.span", "from", Say.time(ended.startedAt), "to", Say.time(ended.endedAt)))
                .font(Type.body(16)).foregroundStyle(Palette.muted)
            Text(receiptLine)
                .font(Type.display(44)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(whereLine)
                .font(Type.body(17)).foregroundStyle(Palette.ink2)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: placeEvenings)
        }
    }

    /// Your evenings. The mark on the left fills tonight's dot; the words on
    /// the right move up by one as it does.
    private var evenings: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                EveningMark(layout: landed ? landing.after : landing.before)
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("end.evenings.label")).eyebrow(Palette.muted)
                    Text(countLine)
                        .font(Type.display(22)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                }
            }
            Text(bodyLine)
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    /// "An hour and a half, all yours." — or "…, the three of you."
    private var receiptLine: String {
        let duration = Say.spokenDuration(minutes: ended.minutes)
        return ended.people <= 1
            ? t("end.receipt.solo", "duration", duration)
            : t("end.receipt", "duration", duration, "count", Say.number(ended.people))
    }

    private var whereLine: String {
        guard let place = ended.place else { return t("end.where.unnamed") }
        switch placeEvenings {
        case .some(1):                return t("end.place.first", "place", place)
        case .some(let n) where n > 1: return t("end.place", "count", Say.number(n), "place", place)
        default:                      return t("end.where", "place", place)
        }
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
        if landing.lands { Sensation.landed() }
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

private extension AppState.Ended {
    static func sample(minutes: Int, people: Int, place: String?, placeId: UUID? = nil) -> Self {
        let now = Date()
        return .init(startedAt: now.addingTimeInterval(-Double(minutes) * 60), endedAt: now,
                     minutes: minutes, people: people, place: place, placeId: placeId,
                     landing: EveningLanding(total: EveningTotal(count: 26, first: "2026-06-03"),
                                             known: [], localDate: PlainDate.string(from: now),
                                             minutes: minutes))
    }
}
