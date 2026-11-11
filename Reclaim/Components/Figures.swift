import SwiftUI
import ReclaimKit

/// Figures in the display face, each over its label, side by side and split
/// by hairlines. Sits along the foot of a card: the box's in Settings, and
/// what it has become on its own page.
struct Figures: View {
    struct Item: Hashable {
        let value: String
        let label: String
    }

    let items: [Item]
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value).font(Type.display(size)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(item.label).font(Type.body(12)).foregroundStyle(Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Palette.line).frame(width: 1) }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

#Preview {
    Figures(items: [
        Figures.Item(value: "112h", label: t("box.kept.hours")),
        Figures.Item(value: "63h", label: t("box.kept.together", "month", "September")),
    ])
    .paperCard(padding: 0)
    .padding()
    .background(Palette.bone)
}
