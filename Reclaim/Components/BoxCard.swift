import SwiftUI
import ReclaimKit

/// One box in Settings: its name, its radio as a dot and a word, and what it
/// has kept, added up — everyone's days at it, never whose. The whole card
/// opens the box's page, which the chevron says.
struct BoxCard: View {
    let name: String
    var status: StatusDot.Style?
    var statusText: String?
    var figures: [Figures.Item] = []

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
            if !figures.isEmpty { Figures(items: figures) }
        }
        .contentShape(Rectangle())
        .paperCard(padding: 0)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 10) {
        BoxCard(name: t("box.default.1"), status: .on, statusText: t("settings.row.connected"),
                figures: [Figures.Item(value: "63h", label: t("box.kept.together", "month", "September"))])
        BoxCard(name: t("box.default.2"), status: .quiet, statusText: t("settings.row.unpaired"))
    }
    .padding()
    .background(Palette.bone)
}
