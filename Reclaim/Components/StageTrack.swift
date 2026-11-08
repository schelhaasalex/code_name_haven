import SwiftUI
import ReclaimKit

/// What a box has become, as a line: a mark for day one and each stage, the
/// way along it filled, and gold where the box stands. It shows the way
/// without counting down to it — no "16 to go".
struct StageTrack: View {
    /// Under each mark, in order: day one, then each stage's day.
    let marks: [String]
    /// How far along, 0 to 1 (`BoxStage.position`).
    let position: Double
    /// Marks reached, day one included. The last of them is gold.
    let reached: Int

    private static let node: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width - Self.node, 0)
            let step = width / CGFloat(max(marks.count - 1, 1))
            ZStack(alignment: .topLeading) {
                Capsule().fill(Palette.line)
                    .frame(width: width, height: 2).offset(x: Self.node / 2, y: Self.node / 2 - 1)
                Capsule().fill(Palette.ink)
                    .frame(width: width * CGFloat(position), height: 2).offset(x: Self.node / 2, y: Self.node / 2 - 1)
                ForEach(marks.indices, id: \.self) { i in
                    mark(i).offset(x: step * CGFloat(i))
                }
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private func mark(_ i: Int) -> some View {
        let here = i == reached - 1
        let past = i < reached - 1
        return VStack(spacing: 6) {
            Circle()
                .fill(here ? Palette.starGold : past ? Palette.ink : Palette.paper)
                .overlay {
                    if !here && !past { Circle().strokeBorder(Palette.hairline, lineWidth: 1.5) }
                }
                .background {
                    if here { Circle().fill(Palette.starGold.opacity(0.25)).padding(-4) }
                }
                .frame(width: Self.node, height: Self.node)
            Text(marks[i]).font(Type.body(11)).foregroundStyle(Palette.muted).fixedSize()
        }
        .frame(width: Self.node)
    }
}

#Preview {
    VStack(spacing: 40) {
        ForEach([0, 3, 34, 140, 400], id: \.self) { days in
            StageTrack(marks: [t("box.become.start")] + BoxStage.days.map { "\($0)" },
                       position: BoxStage.position(evenings: days),
                       reached: BoxStage.reached(evenings: days) + 1)
        }
    }
    .padding(32)
    .background(Palette.paper)
}
