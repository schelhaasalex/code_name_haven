import SwiftUI
import ReclaimKit

/// The heavy one. There is at most one per screen — if a screen seems to need
/// two, one of them is a `QuietButton`.
struct PrimaryButton: View {
    let title: String
    var night: Bool = false
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Type.body(17, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 60)
                .foregroundStyle(night ? Palette.night : Palette.bone)
                .background(tint ?? (night ? Palette.cream : Palette.ink), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: t("home.primary")) {}
        PrimaryButton(title: t("session.end"), night: true) {}
            .padding().background(Palette.night)
    }
    .padding()
}
