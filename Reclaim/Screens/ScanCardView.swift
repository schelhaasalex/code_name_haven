import SwiftUI
import AVFoundation
import VisionKit
import ReclaimKit

/// Scanning a place's card: the printed QR code by camera, or its tag if it
/// has one and the phone can read it.
///
/// The QR is what nearly every card will have — printing is free, a tag is
/// not — and the Camera app can only hand a link to Reclaim once the domain
/// is set up, so the app reads it itself. The camera is asked for the first
/// time this opens, never before, and declining costs nothing: picking a
/// place still works, and Somewhere counts the same (rule 7).
struct ScanCardView: View {
    /// Called once, with a card's URL. The caller routes it through
    /// `URLRouter`, the same path as a tag tapped on the way in.
    let onFound: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var access: Access = .asking
    @State private var notACard = false
    @State private var found = false

    enum Access { case asking, granted, denied, noCamera }

    /// Whether offering "Scan the card" means anything on this phone.
    static var isPossible: Bool { DataScannerViewController.isSupported || TagSession.canRead }

    var body: some View {
        ZStack(alignment: .bottom) {
            if access == .granted {
                CardCamera(onCode: read).ignoresSafeArea()
            } else {
                Palette.night.ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: t("scan.eyebrow"), mark: Palette.ember, tint: Palette.dust)
                Text(message).font(Type.display(26)).foregroundStyle(Palette.cream)
                if notACard {
                    Text(t("scan.notcard")).font(Type.note).foregroundStyle(Palette.dust)
                }
                if access == .denied {
                    QuietButton(title: t("scan.settings"), night: true, action: openSettings)
                }
                if TagSession.canRead {
                    TextAction(title: access == .noCamera ? t("scan.tag.start") : t("scan.tag"),
                               tint: Palette.dust, icon: "wave.3.right", action: readTag)
                }
                TextAction(title: t("scan.close"), tint: Palette.dust) { dismiss() }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.nightCard.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .task { access = await Self.ask() }
    }

    private var message: String {
        switch access {
        case .asking, .granted: t("scan.title")
        case .denied:           t("scan.denied")
        case .noCamera:         t("scan.tag.only")
        }
    }

    private static func ask() async -> Access {
        guard DataScannerViewController.isSupported else { return .noCamera }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return .granted
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default:             return .denied
        }
    }

    /// The camera keeps looking until it sees one of ours; anything else gets
    /// a quiet "not a card" and the scanning carries on.
    private func read(_ text: String) {
        guard !found else { return }
        guard let url = Handle.cardURL(fromScanned: text) else {
            notACard = true
            return
        }
        found = true
        onFound(url)
    }

    private func readTag() {
        TagSession.read { url in
            guard !found else { return }
            found = true
            onFound(url)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ScanCardView { _ in }
}
