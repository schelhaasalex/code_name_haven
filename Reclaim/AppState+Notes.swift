import Foundation
import ActivityKit
import ReclaimKit

/// Noting what goes wrong, for whoever runs the boxes (`Note`, migration
/// 0021). Never waited on and never retried: a note that doesn't arrive is a
/// note, not an evening (rule 7).
@MainActor
extension AppState {

    func note(_ note: Note, place: UUID? = nil, detail: [String: String] = [:], boots: Int? = nil) {
        guard NoteLog.take(note, place: place, boots: boots) else { return }
        let repo = repo
        Task { try? await repo.note(note, place: place, detail: detail) }
    }

    /// The states worth knowing about, looked at on every load: a phone with a
    /// box but no ring on its lock screen, or no Bluetooth to hear the box.
    func noteHowThingsAre() {
        guard let place = boxPlace else { return }
        if !ActivityAuthorizationInfo().areActivitiesEnabled { note(.activitiesOff, place: place) }
        if radio(of: place) == .off { note(.bluetoothOff, place: place) }
    }

    /// A box said how it is.
    func heard(_ hello: Box.Hello, from radio: UUID) {
        guard let place = BoxPairing.place(of: radio) else { return }
        note(.boxHello, place: place, detail: hello.detail, boots: hello.boots)
    }
}
