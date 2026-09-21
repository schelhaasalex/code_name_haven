import SwiftUI
import ReclaimKit

/// Label on the left, a display-face figure on the right.
struct StatRow: View {
    let title: String
    var subtitle: String?
    let value: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(Type.note).foregroundStyle(Palette.muted)
                }
            }
            Spacer()
            Text(value).font(Type.display(28)).foregroundStyle(Palette.ink)
        }
    }
}

#Preview {
    PaperCard {
        StatRow(title: t("places.somewhere.title"),
                subtitle: t("places.somewhere.action"),
                value: Say.duration(minutes: 134))
    }
    .padding()
    .background(Palette.bone)
}
