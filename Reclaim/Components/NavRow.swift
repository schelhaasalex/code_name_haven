import SwiftUI
import ReclaimKit

/// A card that is a way somewhere else: an icon, a title, the chevron.
struct NavRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Palette.ink2).frame(width: 22)
            Text(title).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.hairline)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .paperCard(padding: 0)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavRow(icon: "hand.raised", title: t("settings.privacy"))
        .padding()
        .background(Palette.bone)
}
