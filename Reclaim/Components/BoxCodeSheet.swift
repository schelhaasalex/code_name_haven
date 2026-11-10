import SwiftUI
import ReclaimKit

/// The box's code, on this phone's screen, for another phone to scan as it
/// would the card — the way in once the card is lost, or just across the room.
///
/// Takes the link rather than the app's state, so it previews: the box page asks
/// the server for a fresh code each time it opens this, and passes nil until
/// it has one. `failed` is the server not answering; "Try again" asks again.
struct BoxCodeSheet: View {
    let link: URL?
    let failed: Bool
    let retry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t("code.headline")).font(Type.subhead).foregroundStyle(Palette.ink)
            Text(t(failed ? "code.failed" : "code.body"))
                .font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            code
                .padding(.top, 28)
                .frame(maxWidth: .infinity)
            if failed {
                PrimaryButton(title: t("code.again"), action: retry).padding(.top, 28)
            }
            Button { dismiss() } label: {
                Text(t("code.close")).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .presentationDetents([.large])
        .presentationBackground(Palette.bone)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
    }

    /// Drawn a module to a pixel and scaled with no smoothing, so its edges
    /// stay as sharp as the printed one's. A quiet square until there is one.
    @ViewBuilder private var code: some View {
        let side: CGFloat = 248
        Group {
            if let link, let image = QRCode.image(for: link.absoluteString) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            } else if failed {
                Image(systemName: "qrcode").font(.system(size: 56, weight: .light))
                    .foregroundStyle(Palette.hairline)
            } else {
                ProgressView().tint(Palette.muted)
            }
        }
        .frame(width: side, height: side)
        .padding(16)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
    }
}

#Preview("A code") {
    Color.clear.sheet(isPresented: .constant(true)) {
        BoxCodeSheet(link: Dock.url(secret: "sample-code-for-the-kitchen-table-0000000000", box: "0ACEC38D"),
                     failed: false) {}
    }
}

#Preview("Couldn't make one") {
    Color.clear.sheet(isPresented: .constant(true)) {
        BoxCodeSheet(link: nil, failed: true) {}
    }
}
