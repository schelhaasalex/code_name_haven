import SwiftUI
import AVFoundation
import ReclaimKit

/// Meeting the box from inside the app: the card that came with it, read by
/// the camera, and then the few seconds the phone spends listening for the
/// box's radio — the one moment in setup anyone waits on, so it says what's
/// happening.
///
/// One mark carries it (`PairingMark`): the frame the card is held to becomes
/// the mark as the card is read and the camera fades to paper; it reaches out
/// while the phone listens, and closes when the box is heard.
///
/// The card is the box's code (`Dock.Link` with no slot). Any other QR code is
/// ignored, and a slot's tag link read here only pairs: a phone in a hand
/// isn't in the box.
struct ScanView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage = .asking

    enum Stage { case asking, looking, found, failed, denied }

    private var onCamera: Bool { stage == .asking || stage == .looking }

    var body: some View {
        ZStack {
            Palette.bone.ignoresSafeArea()
            if onCamera {
                ZStack {
                    Palette.night
                    if stage == .looking { CardCamera(onCode: read) }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
            VStack(spacing: 0) {
                closeRow
                Spacer()
                PairingMark(phase: phase)
                words.padding(.top, onCamera ? 28 : 8)
                Spacer()
                Spacer()
                actions
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.25 : 0.5), value: stage)
        .animation(.easeInOut(duration: 0.35), value: state.pairing)
        .preferredColorScheme(onCamera ? .dark : .light)
        .sensoryFeedback(.impact(weight: .light), trigger: stage) { _, now in now == .found }
        .sensoryFeedback(.success, trigger: state.pairing) { _, now in stage == .found && now == .paired }
        .task { await askForCamera() }
        .onChange(of: state.pairing) { _, now in
            guard stage == .found, now == .paired else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                dismiss()
            }
        }
    }

    private var phase: PairingMark.Phase {
        switch stage {
        case .asking, .looking: return .frame
        case .failed, .denied:  return .quiet
        case .found:
            switch state.pairing {
            case .paired:   return .paired
            case .notHeard: return .quiet
            default:        return .listening
            }
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                    .foregroundStyle(onCamera ? Palette.cream : Palette.ink2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(t("scan.close"))
        }
        .opacity(stage == .found && state.pairing != .notHeard ? 0 : 1)
    }

    // MARK: The words

    /// On the camera, one line; after, a headline and its line, crossfading
    /// as they change.
    private var words: some View {
        VStack(spacing: 10) {
            if onCamera {
                Text(t("scan.prompt")).font(Type.lede).foregroundStyle(Palette.cream)
            } else {
                Text(t(keys.headline)).font(Type.display(32)).foregroundStyle(Palette.ink)
                    .id(keys.headline)
                    .transition(.opacity)
                Text(t(keys.body)).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
                    .id(keys.body)
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .frame(minHeight: 96, alignment: .top)
    }

    /// Copy keys for the stage, and for the radio once the card has been read.
    private var keys: (headline: String, body: String) {
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
                if stage == .found, state.pairing == .notHeard, let place = state.lastBox {
                    PrimaryButton(title: t("scan.again")) { state.pairBox(place: place) }
                    TextAction(title: t("scan.later")) { dismiss() }
                }
            }
        }
        .frame(minHeight: 120, alignment: .bottom)
        .transition(.opacity)
    }

    // MARK: The camera

    private func read(_ text: String) {
        guard stage == .looking, let url = URL(string: text), let link = Dock.link(from: url) else { return }
        state.pairing = nil
        stage = .found
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
        if stage == .denied { state.note(.cameraDenied) }
    }
}

#Preview("Scanning") {
    ScanView().environment(AppState(repo: PreviewRepository(places: []), boxPlaces: []))
}
