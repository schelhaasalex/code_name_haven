import SwiftUI
import AVFoundation
import ReclaimKit

/// Meeting the box from inside the app: the card that came with it, read by
/// the camera, and then the few seconds the phone spends listening for the
/// box's radio — the one moment in setup anyone waits on, so it says what's
/// happening.
///
/// The card is the box's code (`Dock.Link` with no slot). Any other QR code is
/// ignored, and a slot's tag link read here only pairs: a phone in a hand
/// isn't in the box.
struct ScanView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .asking

    enum Stage { case asking, looking, found, failed, denied }

    var body: some View {
        Group {
            switch stage {
            case .asking, .looking: camera
            case .found, .failed, .denied: answer.ground()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: stage)
        .animation(.easeInOut(duration: 0.35), value: state.pairing)
        .sensoryFeedback(.success, trigger: stage) { _, now in now == .found }
        .task { await askForCamera() }
        .onChange(of: state.pairing) { _, now in
            guard stage == .found, now == .paired else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                dismiss()
            }
        }
    }

    // MARK: The camera

    private var camera: some View {
        ZStack {
            Palette.night.ignoresSafeArea()
            if stage == .looking { CardCamera(onCode: read).ignoresSafeArea() }
            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Palette.cream).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(t("scan.close"))
                }
                Spacer()
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Palette.cream.opacity(0.9), lineWidth: 2)
                    .frame(width: 248, height: 248)
                Text(t("scan.prompt"))
                    .font(Type.lede).foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }

    private func read(_ text: String) {
        guard stage == .looking, let url = URL(string: text), let link = Dock.link(from: url) else { return }
        stage = .found
        state.pairing = nil
        Task {
            if await !state.dock(Dock.Link(secret: link.secret, slot: nil)) { stage = .failed }
        }
    }

    private func askForCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    stage = .looking
        case .notDetermined: stage = await AVCaptureDevice.requestAccess(for: .video) ? .looking : .denied
        default:             stage = .denied
        }
    }

    // MARK: What came of it

    private var answer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("scan.eyebrow"))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 16) {
                Text(t(words.headline)).font(Type.hero).foregroundStyle(Palette.ink)
                Text(t(words.body)).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            }
            Spacer(minLength: 20)
            actions
        }
    }

    /// Copy keys for the stage, and for the radio once the card has been read.
    private var words: (headline: String, body: String) {
        switch stage {
        case .failed: return ("scan.failed.headline", "scan.failed.body")
        case .denied: return ("scan.denied.headline", "scan.denied.body")
        default:
            switch state.pairing {
            case .paired:   return ("scan.paired.headline", "scan.paired.body")
            case .notHeard: return ("scan.notheard.headline", "scan.notheard.body")
            default:        return ("scan.found.headline", "scan.found.body")
            }
        }
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 12) {
            switch stage {
            case .failed:
                PrimaryButton(title: t("scan.again")) { stage = .looking }
                TextAction(title: t("scan.later")) { dismiss() }
            case .denied:
                PrimaryButton(title: t("scan.settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                TextAction(title: t("scan.later")) { dismiss() }
            default:
                if state.pairing == .notHeard, let place = state.boxPlace {
                    PrimaryButton(title: t("scan.again")) { state.pairBox(place: place) }
                    TextAction(title: t("scan.later")) { dismiss() }
                }
            }
        }
        .frame(minHeight: 120, alignment: .bottom)
    }
}

#Preview("Scanning") {
    ScanView().environment(AppState(repo: PreviewRepository(places: []), boxPlaces: []))
}
