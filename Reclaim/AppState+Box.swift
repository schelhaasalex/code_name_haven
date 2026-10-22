import Foundation
import UIKit
import ReclaimKit

/// The box that notices: a phone set into a slot starts its evening with
/// nobody touching anything.
///
/// The box tells every phone connected to it that a slot filled; each phone
/// asks itself whether that was it (`Box.isThisPhone`), and the one that just
/// started charging, with the box right beside it, starts the evening at the
/// box's place. Putting your phone in the box is the confirmation (rule 4).
/// Taking it out ends nothing.
///
/// All of this happens with the app woken in the background for a few
/// seconds. The tag still works whatever happens here (rule 7).
@MainActor
extension AppState {

    /// At launch, including the background launches the box causes.
    func watchBox() {
        _ = ChargingWatch.shared
        boxLink.resume { [weak self] now, before, rssi in
            guard let self else { return }
            Task { await self.boxChanged(now, before: before, rssi: rssi) }
        }
    }

    /// The first tag read in a box teaches this phone which box is its own.
    /// Asks about Bluetooth, the first time — at the box, where the question
    /// makes sense.
    func pairBox(secret: String, place: UUID) {
        let id = Box.id(secret: secret)
        guard BoxPairing.current?.id != id else { return }
        boxLink.pair(id: id) { peripheral in
            guard let peripheral else { return }
            BoxPairing.current = BoxPairing(peripheral: peripheral, place: place, id: id)
        }
    }

    private func boxChanged(_ now: Box.Slots, before: Box.Slots, rssi: Int?) async {
        // The few seconds iOS gives a Bluetooth wake, stretched to cover a
        // database round trip.
        let task = UIApplication.shared.beginBackgroundTask()
        defer { UIApplication.shared.endBackgroundTask(task) }

        let filled = now.filled(since: before)
        let emptied = now.emptied(since: before)
        if !filled.isEmpty, DockSlot.current == nil {
            await maybeIn(filled, rssi: rssi)
        } else if !emptied.isEmpty, DockSlot.current != nil {
            await maybeOut()
        }
    }

    private func maybeIn(_ filled: Set<Int>, rssi: Int?) async {
        let at = Date()
        let charging = await ChargingWatch.shared.charging(within: 6)
        let fresh = Box.justStarted(chargingSince: ChargingWatch.shared.since, at: at)
        guard Box.isThisPhone(charging: charging, wasCharging: !fresh, rssi: rssi),
              let place = BoxPairing.current?.place
        else { return }

        // Two slots filling at once leaves which one was this phone a guess;
        // the box lights its own slots, so the guess only matters to this phone.
        DockSlot.docked(in: filled.min() ?? 1)
        // Woken in the background, the app may not have looked at anything yet.
        if phase != .ready { await load() }
        guard phase == .ready else { return }
        if isLive {
            await moveHere(place)
        } else {
            await setItDown(place: place, source: .tag)
        }
    }

    /// Somebody's phone came out. Give this one's charger a moment to say
    /// whether it was this one.
    private func maybeOut() async {
        try? await Task.sleep(for: .seconds(2))
        if Box.hasLeft(docked: DockSlot.current != nil, charging: ChargingWatch.shared.isCharging) {
            await DockSlot.undock()
        }
    }
}
