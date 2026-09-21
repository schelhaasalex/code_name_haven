import SwiftUI
import ReclaimKit

/// Eyebrow caps over a stack. Used through settings, places and the place view.
struct LabelledSection<Content: View>: View {
    let label: String
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).eyebrow(Palette.muted)
            VStack(alignment: .leading, spacing: spacing) { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LabelledSection(label: t("settings.how.label")) {
        Text(t("places.somewhere.title")).font(Type.body(15)).foregroundStyle(Palette.ink)
    }
    .padding()
    .background(Palette.bone)
}
