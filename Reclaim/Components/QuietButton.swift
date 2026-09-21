import SwiftUI
import ReclaimKit

/// The light one. Declining is always as easy as accepting — that is most of
/// what keeps this product from nagging.
struct QuietButton: View {
    let title: String
    var night: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Type.body(15, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(night ? Palette.dust : Palette.muted)
                .overlay { if night { Capsule().stroke(Palette.edge, lineWidth: 1) } }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuietButton(title: t("onetap.decline")) {}
        .padding()
        .background(Palette.bone)
}
