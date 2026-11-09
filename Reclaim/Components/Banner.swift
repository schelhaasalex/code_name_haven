import SwiftUI
import ReclaimKit

/// Something that didn't go through, said in a line at the top and gone
/// after a moment. Paper on paper, not a red alert: a rename that didn't
/// save is a thing to try again, not an emergency.
struct Banner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.clay)
            Text(message).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 0)
        .shadow(color: Palette.ink.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    Banner(message: t("error.retry"))
        .padding()
        .background(Palette.bone)
}
