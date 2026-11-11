import SwiftUI
import ReclaimKit

/// Screen 16c. What it's for: the reason in the display face, what it has
/// had since it was chosen, the note, and the way to change or clear it.
/// Reached from Settings, and by tapping Home's headline.
///
/// Its one sentence is days and time since the reason was chosen, from your
/// own sessions only. It says "for", because what the app knows is that the
/// phone was in the box, not what the time went to (rule 6).
struct ReasonView: View {
    /// The way here, from Settings or Home.
    struct Route: Hashable {}

    @Environment(AppState.self) private var state
    @State private var picked: Reason?
    @State private var words = ""
    @State private var kept: (days: Int, minutes: Int)?
    @FocusState private var typing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("reason.page.eyebrow")).eyebrow(Palette.clay)
                    Text(state.reason?.label ?? t("reason.page.none"))
                        .font(Type.title).foregroundStyle(Palette.ink)
                    Text(summary).font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabelledSection(label: t(state.reason == nil ? "reason.page.pick" : "reason.page.change")) {
                    ReasonPicker(picked: $picked, words: $words, typing: $typing)
                }
                if state.reason != nil { note }
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("reason.page.private")).font(Type.note).foregroundStyle(Palette.muted)
                    if state.reason != nil {
                        TextAction(title: t("reason.page.clear"), icon: "minus.circle") { state.choose(nil) }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: state.reason) {
            sync()
            kept = await state.keptSinceReason()
        }
        .onChange(of: picked) { _, _ in if !typing { commit() } }
        .onChange(of: typing) { _, now in if !now { commit() } }
    }

    /// "23 days for the kids, since October, and 41 hours back in all."
    private var summary: String {
        guard let reason = state.reason else { return t("reason.page.none.body") }
        let month = state.reasonSince.flatMap { Say.month(from: PlainDate.string(from: $0)) } ?? ""
        guard let kept, kept.days > 0 else { return t("reason.page.fresh", "month", month) }
        let minutes = kept.minutes >= 60 ? kept.minutes / 60 * 60 : kept.minutes
        let hours = Say.spokenDuration(minutes: minutes)
        return kept.days == 1
            ? t("reason.page.kept.one", "for", reason.purpose, "month", month, "hours", hours)
            : t("reason.page.kept", "count", "\(kept.days)", "for", reason.purpose, "month", month, "hours", hours)
    }

    /// The note's switch: its time once the box has taught one.
    private var note: some View {
        Toggle(isOn: Binding(get: { state.nudging }, set: { on in Task { await state.nudge(on) } })) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.nudgeTime.map { t("reason.page.nudge", "time", $0) } ?? t("reason.page.nudge.later"))
                    .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                Text(t("reason.page.nudge.body")).font(Type.note).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Palette.ink)
        .paperCard()
    }

    /// The picker shows what's kept: on arriving, and after Clear.
    private func sync() {
        picked = state.reason
        if case .own(let w)? = state.reason { words = w }
    }

    /// Kept as soon as it's picked, or, for their own words, once they're done
    /// typing. An empty field keeps what was there.
    private func commit() {
        guard let chosen = Reason.chosen(picked, words: words), chosen != state.reason else { return }
        state.choose(chosen)
    }
}

#Preview("Chosen") {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    state.reason = .kids
    return NavigationStack { ReasonView() }.environment(state).task { await state.load() }
}

#Preview("Not chosen yet") {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    state.reason = nil
    return NavigationStack { ReasonView() }.environment(state).task { await state.load() }
}
