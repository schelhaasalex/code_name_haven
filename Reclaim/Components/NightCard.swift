import SwiftUI
import ReclaimKit

/// `PaperCard`'s counterpart on the session screens.
struct NightCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.nightCard, in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).stroke(Palette.edge, lineWidth: 1) }
    }
}

#Preview {
    NightCard { Text(t("docked.body")).font(Type.body(15)).foregroundStyle(Palette.dust) }
        .padding()
        .background(Palette.night)
}
