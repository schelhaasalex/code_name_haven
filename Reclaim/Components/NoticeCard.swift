import SwiftUI
import ReclaimKit

/// The one thing on a page that needs someone to do something: a clay edge,
/// what's wrong in a sentence, and the way to put it right. It goes first.
struct NoticeCard: View {
    let message: String
    let fix: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.clay)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 0) {
                Text(message).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                TextAction(title: fix, tint: Palette.clay, action: action)
            }
        }
        .padding([.horizontal, .top], 18)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.clay.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.clay.opacity(0.3), lineWidth: 1) }
    }
}

#Preview {
    NoticeCard(message: t("settings.liveactivity.off"), fix: t("settings.liveactivity.fix")) {}
        .padding()
        .background(Palette.bone)
}
