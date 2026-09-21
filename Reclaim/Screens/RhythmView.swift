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
                    Text(state.rhythm.state == .inRhythm
                         ? t("rhythm.headline")
                         : t("rhythmended.headline"))
                        .font(Type.display(46)).foregroundStyle(Palette.ink)
                    if state.rhythm.state == .inRhythm {
                        Text(t("rhythm.subhead", "count", Say.number(state.rhythm.currentRunDays)))
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
        let cells = lastFourWeeks
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 7),
                         spacing: 9) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                RoundedRectangle(cornerRadius: 9)
                    .fill(fill(day))
                    .frame(height: 32)
                    .overlay { stroke(day) }
            }
        }
    }

    private enum Day { case docked, missed, rest, future }

    private func fill(_ day: Day) -> Color {
        switch day {
        case .docked: Palette.ink
        case .missed: Palette.line
        case .rest:   Palette.restFill
        case .future: .clear
        }
    }

    @ViewBuilder private func stroke(_ day: Day) -> some View {
        switch day {
        case .rest:   RoundedRectangle(cornerRadius: 9).stroke(Palette.restStroke, lineWidth: 1.5)
        case .future: RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        default:      EmptyView()
        }
    }

    private var lastFourWeeks: [Day] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: .now)
        guard let start = cal.date(byAdding: .day, value: -27, to: today) else { return [] }
        return (0..<28).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return .future }
            if day > today { return .future }
            return state.evenings.contains(PlainDate.string(from: day)) ? .docked : .missed
        }
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
