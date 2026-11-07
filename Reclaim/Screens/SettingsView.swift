import SwiftUI
import ActivityKit
import AuthenticationServices
import ReclaimKit

/// Screen 16. Deliberately thin: your boxes, each a page of its own
/// (`BoxView`); keeping your evenings with an Apple ID, if you want to; and
/// the way out. "How it works" states the rules as facts rather than offering
/// them as dials, because a household tuning its own minimum is setup by
/// another name.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var scanning = false
    @State private var confirmingDelete = false
    /// The Sign in with Apple request's nonce, kept for its answer.
    @State private var nonce = ""

    /// A box's own page.
    struct BoxRoute: Hashable { let id: UUID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text(t("settings.title")).font(Type.title).foregroundStyle(Palette.ink)
                if !state.boxPlaces.isEmpty { boxes }
                if !ActivityAuthorizationInfo().areActivitiesEnabled { lockScreen }
                if state.kept != nil { keep }
                about
                Spacer(minLength: 8)
                footer
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: BoxRoute.self) { BoxView(id: $0.id) }
        .fullScreenCover(isPresented: $scanning) { ScanView() }
        .confirmationDialog(t("settings.delete"), isPresented: $confirmingDelete) {
            Button(t("settings.delete"), role: .destructive) {
                Task { await state.deleteAccount() }
            }
        } message: {
            Text(t("settings.delete.body"))
        }
        .confirmationDialog(t("settings.elsewhere.title"),
                            isPresented: Binding(get: { state.keptElsewhere != nil },
                                                 set: { if !$0 { state.keptElsewhere = nil } }),
                            titleVisibility: .visible) {
            Button(t("settings.elsewhere.switch")) { Task { await state.useKeptElsewhere() } }
        } message: {
            Text(t("settings.elsewhere.body"))
        }
    }

    // MARK: Boxes

    private var boxes: some View {
        LabelledSection(label: t(state.boxPlaces.count > 1 ? "settings.boxes.label" : "settings.box.label")) {
            ForEach(state.boxPlaces, id: \.self) { id in
                NavigationLink(value: BoxRoute(id: id)) {
                    BoxRow(name: state.name(of: id), detail: detail(id))
                }
                .buttonStyle(.plain)
            }
            TextAction(title: t("settings.add"), tint: Palette.ink2, icon: "plus") { scanning = true }
        }
    }

    /// What its radio is doing, and what it has kept — each only once known.
    private func detail(_ id: UUID) -> String? {
        let radio: String? = switch state.radio(of: id) {
        case .connected: t("settings.row.connected")
        case .away:      t("settings.row.away")
        case .off:       t("settings.row.off")
        case nil:        state.hasRadio(id) ? nil : t("settings.row.unpaired")
        }
        let evenings: String? = state.boxSummaries[id].map { summary in
            let month = Say.month(from: summary.since) ?? ""
            switch summary.evenings {
            case 0:     return t("settings.row.evenings.none")
            case 1:     return t("settings.row.evenings.one", "month", month)
            case let n: return t("settings.row.evenings", "count", "\(n)", "month", month)
            }
        }
        guard let radio, let evenings else { return radio ?? evenings }
        return t("settings.row.joined", "radio", radio, "evenings", evenings)
    }

    // MARK: The lock screen and the account

    /// Only when the ring can't show: otherwise it silently never appears,
    /// and nobody knows why.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t("settings.liveactivity.off")).font(Type.body(15)).foregroundStyle(Palette.ink)
            TextAction(title: t("settings.liveactivity.fix"), tint: Palette.clay, action: openSettings)
        }
        .paperCard()
    }

    /// Optional, and never asked for anywhere else: the account is silent
    /// until someone wants their evenings to outlive this phone.
    private var keep: some View {
        LabelledSection(label: t("settings.keep.label")) {
            if state.kept == true {
                Text(t("settings.kept")).font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
            } else {
                Text(t("settings.keep.body")).font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
                SignInWithAppleButton(.continue) { request in
                    nonce = AppleNonce.make()
                    request.requestedScopes = []
                    request.nonce = AppleNonce.hashed(nonce)
                } onCompletion: { result in
                    Task { await state.keep(result, nonce: nonce) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(Capsule())
                .padding(.top, 4)
            }
        }
    }

    // MARK: About, and the way out

    private var about: some View {
        VStack(alignment: .leading, spacing: 28) {
            LabelledSection(label: t("settings.how.label")) {
                ForEach(1...3, id: \.self) { i in
                    Text(t("settings.how.\(i)"))
                        .font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
                }
            }
            LabelledSection(label: t("settings.see.label")) {
                Text(t("settings.see.body"))
                    .font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(2)
            }
        }
    }

    /// App Store guideline 5.1.1(v) — deletion must be in-app, and easy to
    /// find. It needn't be loud: the weight belongs to the confirmation.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button { confirmingDelete = true } label: {
                Text(t("settings.delete")).font(Type.note).foregroundStyle(Palette.muted)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            Text(version).font(Type.note).foregroundStyle(Palette.hairline)
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        return t("settings.version",
                 "version", info?["CFBundleShortVersionString"] as? String ?? "",
                 "build", info?["CFBundleVersion"] as? String ?? "")
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

#Preview {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return NavigationStack { SettingsView() }.environment(state).task { await state.load() }
}
