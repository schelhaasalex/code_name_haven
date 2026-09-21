import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import ReclaimKit

/// The square on the card. Encodes the same https link the tag carries, so a
/// phone with no NFC — or one whose owner would rather not tap a stranger's
/// card — reaches the same place by camera.
///
/// Correction level H: this gets printed, stuck to a fridge, and lived with.
struct QRCode: View {
    let url: URL
    var size: CGFloat = 176
    var tint: Color = Palette.ink

    private let rendered: UIImage?

    init(url: URL, size: CGFloat = 176, tint: Color = Palette.ink) {
        self.url = url
        self.size = size
        self.tint = tint
        self.rendered = Self.image(for: url)
    }

    var body: some View {
        Group {
            if let rendered {
                Image(uiImage: rendered)
                    .interpolation(.none)      // keep the modules crisp
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Palette.line)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func image(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg).withRenderingMode(.alwaysTemplate)
    }
}

#Preview {
    QRCode(url: Handle.cardURL(secret: "a-preview-secret"))
        .padding()
        .background(Palette.paper)
}
