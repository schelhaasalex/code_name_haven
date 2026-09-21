import SwiftUI
import ReclaimKit

/// The card itself — the thing that gets printed, stuck to a fridge, and lived
/// with for a year. Drawn as a view rather than a PDF so the same code renders
/// it on screen, into a share sheet, and into a printer.
///
/// It carries the handle in plain words and the secret only inside the code.
/// Saying the handle out loud tells someone which card you mean; it does not
/// let them join an evening.
struct CardFace: View {
    let name: String
    let handle: String
    let url: URL

    var body: some View {
        VStack(spacing: 18) {
            Eyebrow(text: t("app.name"))

            Text(name)
                .font(Type.display(28))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)

            QRCode(url: url, size: 168)

            VStack(spacing: 7) {
                Text(Handle.pretty(handle))
                    .font(Type.body(15, weight: .medium))
                    .foregroundStyle(Palette.ink2)
                Text(t("card.instruction"))
                    .font(Type.note)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    CardFace(name: "The Kitchen Table",
             handle: "amber-otter",
             url: Handle.cardURL(secret: "a-preview-secret"))
        .padding()
        .background(Palette.bone)
}
