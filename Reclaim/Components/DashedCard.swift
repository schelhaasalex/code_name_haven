import SwiftUI
import ReclaimKit

/// A dashed outline — for something that exists but hasn't been given a name.
/// Never framed as a deficiency: "Somewhere" is a valid, permanent state.
struct DashedCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
    }
}

#Preview {
    DashedCard {
        Text(t("places.somewhere.title")).font(Type.display(21)).foregroundStyle(Palette.ink2)
    }
    .padding()
    .background(Palette.bone)
}
