import Foundation
import CoreBluetooth

/// Pairing: listening for docks for a few seconds after a box's card or tag
/// is read, and keeping the closest one that isn't already another of this
/// phone's boxes (`Box.closest`).
extension BoxLink {

    /// Finds the dock this phone is closest to, other than `except`. Called
    /// the moment a box's card or tag is read, in the foreground and at the
    /// box — so a box that can't be heard (no radio yet, Bluetooth off) is
    /// simply not paired.
    public func pair(except known: Set<UUID> = [], then done: @escaping @MainActor (UUID?) -> Void) {
        paired = done
        except = known
        heard = [:]
        start()
        Task { @MainActor [weak self] in
            let began = ContinuousClock.now
            while ContinuousClock.now - began < Self.giveUp {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.paired != nil else { return }
                if ContinuousClock.now - began >= Self.listen,
                   let closest = Box.closest(self.heard, except: self.except) {
                    self.finishPairing(self.candidates[closest])
                    return
                }
            }
            self?.finishPairing(nil)
        }
    }

    func finishPairing(_ peripheral: CBPeripheral?) {
        guard let done = paired else { return }
        paired = nil
        manager?.stopScan()
        heard = [:]
        candidates = [:]
        if let peripheral, let manager {
            slots[peripheral.identifier] = Box.Slots(bits: 0)
            hold(peripheral, with: manager)
        }
        done(peripheral?.identifier)
    }

    func discoveredCandidate(_ peripheral: CBPeripheral, rssi: Int) {
        // 127 is Core Bluetooth's "couldn't measure".
        guard paired != nil, rssi != 127 else { return }
        candidates[peripheral.identifier] = peripheral
        heard[peripheral.identifier] = max(rssi, heard[peripheral.identifier] ?? .min)
    }
}
