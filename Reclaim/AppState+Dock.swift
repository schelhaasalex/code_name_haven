import Foundation
import UIKit
import ReclaimKit

/// The box half of `AppState`: a phone set into a slot, and taken out again.
///
/// Putting your phone in the box IS the confirmation — the same act as setting
/// it down, with a drawer around it. So a slot's tag starts the evening the way
/// a card does, at the box's place, and its light comes on. Taking the phone
/// out only puts the light out: nobody but the person ends an evening.
@MainActor
extension AppState {

    /// A slot's tag was read. The light first, because it is the instant
    /// answer to "did it take?" — and it is never waited on (rule 7).
    public func dock(_ link: Dock.Link) async {
        // Moved from one slot to another: the one it left goes dark.
        if let left = DockSlot.current, left != link.slot {
            DockLight.shared.set(slot: left, on: false)
        }
        DockSlot.docked(in: link.slot)
        DockLight.shared.set(slot: link.slot, on: true)

        guard let place = await boxPlace(secret: link.secret) else {
            // Not knowing the box's place is no reason not to count tonight.
            if !isLive { await setItDown(source: .tag) }
            return
        }
        PlaceSecrets.save(link.secret, for: place)
        if isLive {
            await moveHere(place)
        } else {
            await setItDown(place: place, source: .tag)
        }
    }

    /// The light of a phone that has quietly left the box. iOS doesn't wake
    /// the app when a phone comes off the pad unless the person added the
    /// charger automation, so every return to the foreground checks. A slot
    /// can stay lit for a phone that's gone; it never goes dark under one
    /// that's there.
    func checkDock() async {
        guard DockSlot.current != nil else { return }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let charging = device.batteryState == .charging || device.batteryState == .full
        if DockSlot.hasLeft(since: DockSlot.since, charging: charging) {
            await DockSlot.undock()
        }
    }

    /// Found, or made by this phone, being the first into the box. A handle
    /// someone else drew comes back nil; three draws from 256 is plenty.
    private func boxPlace(secret: String) async -> UUID? {
        for _ in 0..<3 {
            do {
                if let id = try await repo.dockPlace(secret: secret, handle: Handle.generate()) {
                    return id
                }
            } catch {
                return nil
            }
        }
        return nil
    }
}
