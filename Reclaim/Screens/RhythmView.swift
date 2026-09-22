import SwiftUI
import ReclaimKit

/// Screen 10. A STATE, NOT A RANK — you are in a rhythm or between rhythms.
/// It moves both ways without punishing, because re-entry costs one evening and
/// the days already banked never disappear. No tier, no decay, nothing to lose
/// by not opening the app.
struct RhythmView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: t("rhythm.eyebrow"))

                VStack(alignment: .leading, spacing: 10) {
                    // Never "that rhythm ended" to someone who hasn't had one.
                    Text(state.rhythm.state == .inRhythm ? t("rhythm.headline")
                         : state.rhythm.longestRunDays == 0 ? t("rhythm.none.headline")
                         : t("rhythmended.headline"))
                        .font(Type.display(46)).foregroundStyle(Palette.ink)
                    if state.rhythm.state == .inRhythm {
                        Text(t("rhythm.subhead", "count", Say.number(state.rhythm.currentRunDays)))
                            .font(Type.display(24)).foregroundStyle(Palette.clay)
                    } else if state.rhythm.longestRunDays == 0 {
                        Text(t("rhythm.none.subhead"))
                            .font(Type.display(24)).foregroundStyle(Palette.clay)
                    }
                }

                grid
                legend

                if state.rhythm.longestRunDays > 0 {
                    Text(t("rhythm.longest",
                           "count", Say.number(state.rhythm.longestRunDays),
                           "month", Say.month(from: state.rhythm.lastQualifyingDate) ?? "June"))
                        .font(Type.body(14)).foregroundStyle(Palette.ink2)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(t("rhythm.rest.title"))
                        .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                    Text(t("rhythm.rest.body"))
                        .font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(3)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1) }

                // The promise that makes this survivable with a teenager.
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock").font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                    Text(t("rhythm.privacy"))
                        .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
                }
                .padding(.top, 18)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var grid: some View {
        DayGrid(days: EveningCalendar.grid(evenings: state.evenings, weeks: 4))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(t("rhythm.legend.docked"), fill: Palette.ink, stroke: nil)
            legendItem(t("rhythm.legend.rest"), fill: Palette.restFill, stroke: Palette.restStroke)
            legendItem(t("rhythm.legend.missed"), fill: Palette.line, stroke: nil)
        }
    }

    private func legendItem(_ label: String, fill: Color, stroke: Color?) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 13, height: 13)
                .overlay { if let stroke { RoundedRectangle(cornerRadius: 4).stroke(stroke, lineWidth: 1.5) } }
            Text(label).font(Type.note).foregroundStyle(Palette.muted)
        }
    }
}

#Preview {
    NavigationStack { RhythmView() }.environment(AppState(repo: PreviewRepository()))
}
