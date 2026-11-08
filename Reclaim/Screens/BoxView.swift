import SwiftUI
import ReclaimKit

/// Screen 16a. One box, from Settings: what it has become, what its radio is
/// doing, its name, and the way to let it go — quietly, at the foot.
///
/// It leads with the box's stage, because the place you did it in slowly
/// becoming something is the product. Everyone's days at it added up, never
/// whose.
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
    /// Confirmed in the sheet: once it has gone, the box goes, and this page.
    @State private var forgotten = false
    @State private var scanning = false
    /// Renamed a moment ago, for the field's check.
    @State private var saved = false
    @FocusState private var editing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.name(of: id)).font(Type.title).foregroundStyle(Palette.ink)
                    if let month = Say.month(from: state.boxSummaries[id]?.since) {
                        Text(t("place.stage.since", "month", month))
                            .font(Type.display(17)).foregroundStyle(Palette.muted)
                    }
                }
                if let summary = state.boxSummaries[id] { become(summary) }
                LabelledSection(label: t("box.radio.label")) { radio }
                LabelledSection(label: t("box.name.label")) { nameField }
                Spacer(minLength: 8)
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
        .sheet(isPresented: $confirmingForget, onDismiss: { if forgotten { state.forget(id); dismiss() } }) {
            ConfirmSheet(title: t("settings.forget.title"), message: t("settings.forget.body"),
                         confirm: t("settings.forget"), cancel: t("settings.forget.keep")) {
                forgotten = true
            }
        }
    }

    @ViewBuilder private var nameField: some View {
        if state.canRename(id) {
            NameField(text: $name, placeholder: state.name(of: id), saved: saved,
                      editing: $editing, onSubmit: save)
            Text(t("box.name.shared")).font(Type.note).foregroundStyle(Palette.muted)
        } else {
            Text(state.name(of: id)).font(Type.body(16)).foregroundStyle(Palette.ink)
            Text(t("box.name.locked")).font(Type.note).foregroundStyle(Palette.muted)
        }
    }

    private func save() {
        let new = name.trimmed
        guard state.canRename(id), !new.isEmpty, new != shown else { return }
        shown = new
        Task {
            guard await state.rename(id, to: new) else { return }
            saved = true
            try? await Task.sleep(for: .seconds(1.4))
            saved = false
        }
    }

    /// What it has become: the stage in the display face, the track through
    /// all of them, and what it has kept beneath. Before its first day, only
    /// "Nothing here yet."
    private func become(_ summary: PlaceSummary) -> some View {
        let days = summary.evenings
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("box.become.label")).eyebrow(Palette.muted)
                Text(days == 0 ? t("box.become.none") : t(BoxStage.key(summary.stage)))
                    .font(Type.display(26)).foregroundStyle(Palette.ink)
                StageTrack(marks: [t("box.become.start")] + BoxStage.days.map { "\($0)" },
                           position: BoxStage.position(evenings: days),
                           reached: BoxStage.reached(evenings: days) + 1)
                    .padding(.top, 12)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            if days > 0 {
                Figures(items: [
                    Figures.Item(value: Say.duration(minutes: summary.wallClockMinutes), label: t("box.kept.hours")),
                    Figures.Item(value: "\(days)", label: t("box.kept.evenings")),
                ], size: 30)
            }
        }
        .paperCard(padding: 0)
    }

    /// A dot and a sentence, with its fix beneath when there is one.
    private var radio: some View {
        let status = state.radio(of: id)
        return HStack(alignment: .top, spacing: 12) {
            StatusDot(style: StatusDot.style(status), size: 9).padding(.top, 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(t(radioKey(status))).font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if status == .off {
                    TextAction(title: t("box.radio.settings"), tint: Palette.clay) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } else if !state.hasRadio(id) {
                    TextAction(title: t("box.radio.scan"), tint: Palette.clay) { scanning = true }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
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
        TextAction(title: t("settings.forget"), icon: "minus.circle") { confirmingForget = true }
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
