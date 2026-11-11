import SwiftUI
import ReclaimKit

/// One box in Settings: its name, and its radio as a dot and a word. What it
/// has kept is on its page, said once, beside its stage — three figures here
/// repeated it, and "38 days" never said since when. The whole card opens the
/// box's page, which the chevron says.
struct BoxCard: View {
    let name: String
    var status: StatusDot.Style?
    var statusText: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).font(Type.body(17, weight: .medium)).foregroundStyle(Palette.ink)
                    if let statusText {
                        HStack(spacing: 7) {
                            if let status { StatusDot(style: status) }
                            Text(statusText).font(Type.note).foregroundStyle(Palette.muted)
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.hairline)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .contentShape(Rectangle())
        .paperCard(padding: 0)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 10) {
        BoxCard(name: t("box.default.1"), status: .on, statusText: t("settings.row.connected"))
        BoxCard(name: t("box.default.2"), status: .quiet, statusText: t("settings.row.unpaired"))
    }
    .padding()
    .background(Palette.bone)
}
