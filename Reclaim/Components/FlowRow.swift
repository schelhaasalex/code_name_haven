import SwiftUI
import ReclaimKit

/// A row of things that wraps. Used for the name suggestions on screen 21,
/// where a fixed grid would either clip "The Back Porch" or leave a hole next
/// to "The Deck".
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        return laid(out: subviews, width: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let offsets = laid(out: subviews, width: bounds.width).offsets
        for (view, offset) in zip(subviews, offsets) {
            view.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                       proposal: .unspecified)
        }
    }

    private func laid(out subviews: Subviews, width: CGFloat)
    -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (offsets, CGSize(width: widest, height: y + rowHeight))
    }
}

#Preview {
    FlowRow(spacing: 8) {
        ForEach(["The Kitchen Table", "The Deck", "The Living Room", "The Office"], id: \.self) {
            Text($0).padding(8).background(Palette.linen, in: Capsule())
        }
    }
    .frame(width: 280)
    .padding()
}
