import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// A box's code as a QR, for a phone to show another one. Error correction M
/// and a quiet margin of four modules, as on the printed card
/// (`scripts/dock-tags.sh`), so a phone reads it off a screen as readily.
public enum QRCode {

    /// One pixel per module, margin included; draw it scaled up with no
    /// smoothing. Nil only if Core Image can't make one.
    public static func image(for text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let code = filter.outputImage else { return nil }
        // Core Image leaves one module of margin; the standard asks for four.
        let margin: CGFloat = 3
        let padded = code.transformed(by: CGAffineTransform(translationX: margin, y: margin))
            .composited(over: CIImage(color: .white))
            .cropped(to: code.extent.insetBy(dx: -margin, dy: -margin)
                                    .offsetBy(dx: margin, dy: margin))
        return CIContext().createCGImage(padded, from: padded.extent)
    }
}
