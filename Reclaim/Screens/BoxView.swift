import SwiftUI
import ReclaimKit

/// One box, from Settings: its name, what it has kept, what its radio is
/// doing, and the way to let it go — quietly, at the foot.
///
/// The name saves however the field is left: Done, a tap elsewhere, or Back.
/// Only whoever first scanned the box can change it (`places_update_owner`).
struct BoxView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var name = ""
    /// The name as last put in the field, so only what someone typed is
    /// saved — never a name that arrived late from the database.
    @State private var shown = ""
    @State private var confirmingForget = false
    @State private var scanning = false
    @FocusState private var editing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(state.name(of: id)).font(Type.title).foregroundStyle(Palette.ink)
                LabelledSection(label: t("box.name.label")) { nameField }
                if let summary = state.boxSummaries[id] { kept(summary) }
                LabelledSection(label: t("box.radio.label")) { radio }
                Spacer(minLength: 20)
                forget
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: state.name(of: id)) {
            guard !editing else { return }
            name = state.name(of: id)
            shown = name
        }
        .onChange(of: editing) { _, now in if !now { save() } }
        .onDisappear { save() }
        .fullScreenCover(isPresented: $scanning) { ScanView() }
        .confirmationDialog(t("settings.forget"), isPresented: $confirmingForget) {
            Button(t("settings.forget"), role: .destructive) {
                state.forget(id)
                dismiss()
            }
        } message: {
            Text(t("settings.forget.body"))
        }
    }

    @ViewBuilder private var nameField: some View {
        if state.canRename(id) {
            TextField(state.name(of: id), text: $name)
                .font(Type.body(16)).foregroundStyle(Palette.ink)
                .focused($editing)
                .submitLabel(.done)
                .onSubmit(save)
                .paperCard()
        } else {
            Text(state.name(of: id)).font(Type.body(16)).foregroundStyle(Palette.ink)
            Text(t("box.name.locked")).font(Type.note).foregroundStyle(Palette.muted)
        }
    }

    private func save() {
        let new = name.trimmed
        guard state.canRename(id), !new.isEmpty, new != shown else { return }
        shown = new
        Task { await state.rename(id, to: new) }
    }

    /// Everyone's evenings at it, added up — never whose.
    private func kept(_ summary: PlaceSummary) -> some View {
        LabelledSection(label: t("box.kept.label")) {
            PaperCard {
                VStack(spacing: 14) {
                    StatRow(title: t("box.kept.hours"), value: Say.duration(minutes: summary.wallClockMinutes))
                    StatRow(title: t("box.kept.evenings"), value: "\(summary.evenings)")
                    if let month = Say.month(from: summary.since) {
                        StatRow(title: t("box.kept.since"), value: month)
                    }
                }
            }
        }
    }

    @ViewBuilder private var radio: some View {
        let status = state.radio(of: id)
        Text(t(radioKey(status))).font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
        if status == .off {
            TextAction(title: t("box.radio.settings"), tint: Palette.clay) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        } else if !state.hasRadio(id) {
            TextAction(title: t("box.radio.scan"), tint: Palette.clay) { scanning = true }
        }
    }

    private func radioKey(_ status: BoxLink.Radio?) -> String {
        switch status {
        case .connected: "box.radio.connected"
        case .away:      "box.radio.away"
        case .off:       "box.radio.off"
        // Bluetooth hasn't said anything yet on this launch: what is known is
        // only that the two have met.
        case nil:        state.hasRadio(id) ? "box.radio.paired" : "box.radio.unpaired"
        }
    }

    private var forget: some View {
        Button { confirmingForget = true } label: {
            Text(t("settings.forget")).font(Type.note).foregroundStyle(Palette.muted)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

#Preview {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return NavigationStack { BoxView(id: PreviewRepository.kitchenTable) }
        .environment(state).task { await state.load() }
}
