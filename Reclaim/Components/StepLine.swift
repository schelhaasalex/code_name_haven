import SwiftUI
import ReclaimKit

/// Rules as a line through time: when, in the display face, beside what
/// happens then. A filled mark is a moment that counts. Facts, not dials —
/// nothing here can be changed, and that's the point.
struct StepLine: View {
    struct Step: Hashable {
        let when: String
        let unit: String
        let text: String
        var counts = false
    }

    let steps: [Step]

    /// The column the "when" sits in, and the gap to the line.
    private static let whenWidth: CGFloat = 64
    private static let gap: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                let last = i == steps.count - 1
                HStack(alignment: .top, spacing: Self.gap) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(step.when).font(Type.display(20)).foregroundStyle(Palette.ink)
                        Text(step.unit).font(Type.body(10, weight: .semibold))
                            .textCase(.uppercase).tracking(1.2).foregroundStyle(Palette.muted)
                    }
                    .frame(width: Self.whenWidth, alignment: .trailing)
                    Circle()
                        .fill(step.counts ? Palette.ink : Palette.bone)
                        .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 1.5) }
                        .frame(width: 9, height: 9)
                        .padding(.top, 6)
                    Text(step.text).font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, last ? 0 : 18)
                }
                // The line down to the next mark, drawn behind the row so it
                // runs the row's whole height, however the text wraps.
                .background(alignment: .topLeading) {
                    if !last {
                        Rectangle().fill(Palette.hairline).frame(width: 1)
                            .padding(.top, 15)
                            .padding(.bottom, -6)
                            .padding(.leading, Self.whenWidth + Self.gap + 4)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    StepLine(steps: (1...4).map {
        StepLine.Step(when: t("settings.how.\($0).when"), unit: t("settings.how.\($0).unit"),
                      text: t("settings.how.\($0)"), counts: $0.isMultiple(of: 2))
    })
    .padding(32)
    .background(Palette.bone)
}
