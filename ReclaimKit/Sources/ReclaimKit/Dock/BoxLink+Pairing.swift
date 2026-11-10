import Foundation
import CoreBluetooth

/// Pairing: listening for docks after a box's card is read, and keeping
/// the one the card names — at once, as soon as it's heard — or, for a card
/// that names none, the closest after a few seconds that isn't already another
/// of this phone's boxes (`Box.closest`).
extension BoxLink {

    /// Finds the dock this phone is closest to, other than `except`. Called
    /// the moment a box's card is read, in the foreground and at the
    /// box — so a box that can't be heard (no radio yet, Bluetooth off) is
    /// simply not paired.
    public func pair(except known: Set<UUID> = [], named id: String? = nil,
                     then done: @escaping @MainActor (UUID?) -> Void) {
        paired = done
        except = known
        wanted = id
        heard = [:]
        names = [:]
        start()
        Task { @MainActor [weak self] in
            let began = ContinuousClock.now
            while ContinuousClock.now - began < Self.giveUp {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.paired != nil else { return }
                // Off, or refused at the prompt: nothing will be heard, so
                // say so now rather than after twelve seconds of listening.
                if self.bluetoothOff { break }
                // The card names its box: the moment it's heard, that's it.
                if let id = self.wanted {
                    if let named = Box.closest(self.heard, except: self.except, named: id, names: self.names) {
                        self.finishPairing(self.candidates[named])
                        return
                    }
                    continue
                }
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
        // Docks connected only to be measured, and not kept, go back.
        for (id, other) in candidates where id != peripheral?.identifier && boxes[id] == nil {
            manager?.cancelPeripheralConnection(other)
        }
        heard = [:]
        candidates = [:]
        names = [:]
        wanted = nil
        if let peripheral, let manager {
            slots[peripheral.identifier] = Box.Slots(bits: 0)
            hold(peripheral, with: manager)
        }
        done(peripheral?.identifier)
    }

    /// A dock already connected to this phone never shows up in a scan: it's
    /// talking to the phone, not advertising to it. That's this same box on
    /// a re-pair, or one just forgotten whose link iOS hasn't dropped yet —
    /// and a phone listening only to the air waits for it forever. So ask iOS
    /// which docks it's connected to, and measure each over its link.
    func hearConnected(_ manager: CBCentralManager) {
        let docks = manager.retrieveConnectedPeripherals(withServices: [CBUUID(string: Box.service)])
        for dock in docks where !except.contains(dock.identifier) {
            candidates[dock.identifier] = dock
            if let name = dock.name { names[dock.identifier] = name }
            dock.delegate = self
            if dock.state == .connected { dock.readRSSI() } else { manager.connect(dock) }
        }
    }

    func discoveredCandidate(_ peripheral: CBPeripheral, rssi: Int, name: String?) {
        // 127 is Core Bluetooth's "couldn't measure".
        guard paired != nil, rssi != 127 else { return }
        candidates[peripheral.identifier] = peripheral
        if let name { names[peripheral.identifier] = name }
        heard[peripheral.identifier] = max(rssi, heard[peripheral.identifier] ?? .min)
    }
}
