import SwiftUI
import ReclaimKit

/// A plain text action, left-aligned. Used where a control should read as a
/// sentence rather than a button.
struct TextAction: View {
    let title: String
    var tint: Color = Palette.muted
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 15)) }
                Text(title).font(Type.body(15, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(alignment: .leading) {
        TextAction(title: t("settings.signout")) {}
        TextAction(title: t("settings.delete"), tint: Palette.clay) {}
    }
    .padding()
    .background(Palette.bone)
}
