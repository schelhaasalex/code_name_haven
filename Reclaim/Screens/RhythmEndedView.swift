import SwiftUI
import ReclaimKit

/// Screen 14. The hardest moment in the product to get right.
///
/// The days already banked never disappear, re-entry costs one evening, and the
/// primary action is getting straight back in. Nothing here is a reprimand.
struct RhythmEndedView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let rhythm: Rhythm

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("rhythmended.eyebrow"))
            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("rhythmended.headline"))
                        .font(Type.display(46)).foregroundStyle(Palette.ink)
                    Text(t("rhythmended.subhead"))
                        .font(Type.display(26)).foregroundStyle(Palette.clay)
                }
                Text(t("rhythmended.body", "count", Say.number(rhythm.longestRunDays)))
                    .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            }

            Spacer(minLength: 20)

            VStack(spacing: 18) {
                PrimaryButton(title: t("rhythmended.primary")) {
                    dismiss()
                    Task { await state.setItDown() }
                }
                Text(t("rhythmended.footer"))
                    .font(Type.body(14)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .ground()
    }
}

#Preview {
    RhythmEndedView(rhythm: Rhythm(state: .between, currentRunDays: 0, longestRunDays: 9,
                                   lastQualifyingDate: "2026-09-14", restDayAvailable: true))
        .environment(AppState(repo: PreviewRepository()))
}
