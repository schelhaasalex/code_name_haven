import SwiftUI
import AVFoundation
import ReclaimKit

/// The camera, reading QR codes, full bleed. Hands over every code it reads,
/// as text; what counts as the box's card is the scanner's to decide.
///
/// AVFoundation rather than VisionKit's scanner: this runs on every phone
/// iOS 17 does, draws nothing of its own over the picture, and needs no
/// dependency.
struct CardCamera: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.onCode = onCode
        view.start()
        return view
    }

    func updateUIView(_ view: Preview, context: Context) { view.onCode = onCode }

    static func dismantleUIView(_ view: Preview, coordinator: ()) { view.stop() }

    final class Preview: UIView, AVCaptureMetadataOutputObjectsDelegate {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var onCode: ((String) -> Void)?
        private let session = AVCaptureSession()

        func start() {
            let layer = layer as! AVCaptureVideoPreviewLayer
            layer.session = session
            layer.videoGravity = .resizeAspectFill
            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            // Starting blocks for a moment; never on the main thread.
            let session = session
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }

        func stop() {
            let session = session
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            for case let code as AVMetadataMachineReadableCodeObject in objects {
                if let text = code.stringValue { onCode?(text) }
            }
        }
    }
}

#Preview {
    // The simulator has no camera: this is a dark rectangle there.
    CardCamera { _ in }.ignoresSafeArea()
}
