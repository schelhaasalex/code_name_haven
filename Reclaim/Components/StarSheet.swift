import SwiftUI
import ReclaimKit

/// What today's star is, for whoever taps it on Home. It explains and does
/// nothing else: there is no Start here, because the box is the only switch.
/// Once today has counted, it says so and asks for nothing.
///
/// In ConfirmSheet's paper and shape, sized to what it says.
struct StarSheet: View {
    let place: String
    let counted: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t(counted ? "star.counted.eyebrow" : "star.eyebrow")).eyebrow(Palette.clay)
            Text(counted ? t("star.counted.title") : t("star.title", "place", place))
                .font(Type.subhead).foregroundStyle(Palette.ink)
                .padding(.top, 12)
            Text(t(counted ? "star.counted.body" : "star.body"))
                .font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                .padding(.top, 10)
            TextAction(title: t("star.close"), tint: Palette.clay) { dismiss() }
                .padding(.top, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
        .presentationDetents([.height(height)])
        .presentationBackground(Palette.bone)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
    }
}

#Preview("Waiting") {
    Color.clear.sheet(isPresented: .constant(true)) {
        StarSheet(place: "The Harbor", counted: false)
    }
}

#Preview("Counted") {
    Color.clear.sheet(isPresented: .constant(true)) {
        StarSheet(place: "The Harbor", counted: true)
    }
}
