import SwiftUI
import ReclaimKit

/// The bordered off-white block. Four screens draw this; before it existed they
/// each drew it slightly differently.
struct PaperCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(padding: 0, radius: radius)
    }
}

extension View {
    /// The same block as a modifier, for a control that can't be wrapped
    /// without losing its binding — a Toggle, mainly.
    func paperCard(padding: CGFloat = 18, radius: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).stroke(Palette.line, lineWidth: 1) }
    }
}

#Preview {
    PaperCard { Text(t("settings.nudge.title")).font(Type.body(15)) }
        .padding()
        .background(Palette.bone)
}
