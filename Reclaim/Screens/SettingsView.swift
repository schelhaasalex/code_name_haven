import SwiftUI
import ActivityKit
import AuthenticationServices
import ReclaimKit

/// Screen 16. Deliberately thin: anything that needs fixing first; your
/// boxes, each a page of its own (`BoxView`); keeping your days with an Apple
/// ID, if you want to; how it works; privacy; and the way out. "How it works"
/// states the rules as facts rather than offering them as dials, because a
/// household tuning its own minimum is setup by another name.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var scanning = false
    @State private var confirmingDelete = false
    /// The Sign in with Apple request's nonce, kept for its answer.
    @State private var nonce = ""

    /// A box's own page.
    struct BoxRoute: Hashable { let id: UUID }
    /// What we can see.
    struct PrivacyRoute: Hashable {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("settings.title")).font(Type.title).foregroundStyle(Palette.ink)
                    Text(t("settings.sub")).font(Type.display(17)).foregroundStyle(Palette.muted)
                }
                // Only when the ring can't show: otherwise it silently never
                // appears, and nobody knows why.
                if !ActivityAuthorizationInfo().areActivitiesEnabled {
                    NoticeCard(message: t("settings.liveactivity.off"), fix: t("settings.liveactivity.fix"),
                               action: openSettings)
                }
                if !state.boxPlaces.isEmpty { boxes }
                if state.kept != nil { keep }
                LabelledSection(label: t("settings.how.label")) {
                    StepLine(steps: steps)
                    // iOS won't wake a swiped-away app for Bluetooth, and since
                    // the tags went nothing else can: better heard here than
                    // found out as a day that didn't count.
                    Text(t("settings.how.background")).font(Type.note).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                NavigationLink(value: PrivacyRoute()) {
                    NavRow(icon: "hand.raised", title: t("settings.privacy"))
                }
                .buttonStyle(.plain)
                footer
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: BoxRoute.self) { BoxView(id: $0.id) }
        .navigationDestination(for: PrivacyRoute.self) { _ in PrivacyView() }
        .fullScreenCover(isPresented: $scanning) { ScanView() }
        .sheet(isPresented: $confirmingDelete) {
            ConfirmSheet(title: t("settings.delete.title"), message: t("settings.delete.body"),
                         confirm: t("settings.delete"), cancel: t("settings.delete.keep")) {
                // Gone: back to a Home that starts again, not a Settings
                // page with nothing left in it.
                Task { if await state.deleteAccount() { dismiss() } }
            }
        }
        .sheet(isPresented: Binding(get: { state.keptElsewhere != nil },
                                    set: { if !$0 { state.keptElsewhere = nil } })) {
            ConfirmSheet(title: t("settings.elsewhere.title"), message: t("settings.elsewhere.body"),
                         confirm: t("settings.elsewhere.switch"), cancel: t("settings.elsewhere.stay"),
                         tint: Palette.ink) {
                Task { await state.useKeptElsewhere() }
            }
        }
    }

    // MARK: Boxes

    private var boxes: some View {
        LabelledSection(label: t(state.boxPlaces.count > 1 ? "settings.boxes.label" : "settings.box.label")) {
            ForEach(state.boxPlaces, id: \.self) { id in
                let radio = status(id)
                NavigationLink(value: BoxRoute(id: id)) {
                    BoxCard(name: state.name(of: id), status: radio?.0, statusText: radio?.1,
                            figures: figures(id))
                }
                .buttonStyle(.plain)
            }
            TextAction(title: t("settings.add"), tint: Palette.ink2, icon: "plus") { scanning = true }
        }
    }

    /// What its radio is doing, once Bluetooth has said.
    private func status(_ id: UUID) -> (StatusDot.Style, String)? {
        switch state.radio(of: id) {
        case .connected: return (StatusDot.Style.on, t("settings.row.connected"))
        case .away:      return (StatusDot.Style.quiet, t("settings.row.away"))
        case .off:       return (StatusDot.Style.off, t("settings.row.off"))
        case nil:
            guard !state.hasRadio(id) else { return nil }
            return (StatusDot.Style.quiet, t("settings.row.unpaired"))
        }
    }

    /// What it has kept, added up — only once it has kept something. One
    /// figure, whole hours, with since when as its label: a count of days
    /// beside it said "38" without saying since when, and the month made a
    /// third box. The days are the box's page's, with its stage.
    private func figures(_ id: UUID) -> [Figures.Item] {
        guard let summary = state.boxSummaries[id], summary.evenings > 0 else { return [] }
        let minutes = summary.wallClockMinutes
        let label = Say.month(from: summary.since).map { t("box.kept.together", "month", $0) } ?? t("box.kept.hours")
        return [Figures.Item(value: Say.duration(minutes: minutes >= 60 ? minutes / 60 * 60 : minutes), label: label)]
    }

    // MARK: Your days, and how it works

    /// Optional, and never asked for anywhere else: the account is silent
    /// until someone wants their days to outlive this phone.
    private var keep: some View {
        LabelledSection(label: t("settings.keep.label")) {
            if state.kept == true {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(Palette.linen, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("settings.kept.title")).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                        Text(t("settings.kept")).font(Type.note).foregroundStyle(Palette.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .paperCard()
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 14) {
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
                }
                .paperCard()
            }
        }
    }

    /// In, fifteen minutes, five seconds, three hours: the marks that count
    /// are filled.
    private var steps: [StepLine.Step] {
        (1...4).map { i in
            StepLine.Step(when: t("settings.how.\(i).when"), unit: t("settings.how.\(i).unit"),
                          text: t("settings.how.\(i)"), counts: i.isMultiple(of: 2))
        }
    }

    // MARK: The way out

    /// App Store guideline 5.1.1(v) — deletion must be in-app, and easy to
    /// find. It needn't be loud: the weight belongs to the confirmation.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextAction(title: t("settings.delete"), icon: "trash") { confirmingDelete = true }
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
