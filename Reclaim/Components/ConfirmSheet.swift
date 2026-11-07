import SwiftUI
import ReclaimKit

/// Asking before something that's hard to take back — forgetting a box,
/// deleting an account, trading one account for another. In the app's own
/// paper and type: iOS's dialog arrived anchored to the button, in system red,
/// and read as somebody else's app. Sized to what it says, and swiped away to
/// leave things as they were.
///
/// It closes itself before acting, so anything that should follow it — going
/// back a screen — belongs in the presenting sheet's `onDismiss`.
struct ConfirmSheet: View {
    let title: String
    let message: String
    let confirm: String
    let cancel: String
    var tint: Color = Palette.clay
    let action: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(Type.subhead).foregroundStyle(Palette.ink)
            Text(message).font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                .padding(.top, 12)
            PrimaryButton(title: confirm, tint: tint) {
                dismiss()
                action()
            }
            .padding(.top, 28)
            Button { dismiss() } label: {
                Text(cancel).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
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

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ConfirmSheet(title: t("settings.delete.title"), message: t("settings.delete.body"),
                     confirm: t("settings.delete"), cancel: t("settings.delete.keep")) {}
    }
}
