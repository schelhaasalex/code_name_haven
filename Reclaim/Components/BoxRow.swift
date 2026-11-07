import SwiftUI
import ReclaimKit

/// One box in Settings' list: its name, a quiet line about it, and the
/// chevron that says there's more.
struct BoxRow: View {
    let name: String
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(Type.body(16, weight: .medium)).foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail).font(Type.note).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.hairline)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .paperCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 10) {
        BoxRow(name: t("box.default.1"), detail: t("settings.row.connected"))
        BoxRow(name: t("box.default.2"))
    }
    .padding()
    .background(Palette.bone)
}
