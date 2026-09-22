import Foundation
import CoreBluetooth

/// The phone still in your hand, listening for a table that is already set.
///
/// FOREGROUND ONLY, deliberately. The moment this is for is the one where you
/// are holding the phone and about to put it down; scanning through the
/// evening would cost battery to hear nothing, and asking to scan in the
/// background would be a permission this feature hasn't earned. The phone
/// that is DOWN is the one that keeps talking in the background — see
/// `NearbyBeacon`.
///
/// It only ever offers (rule 4). Finding a table produces a question on
/// screen 4; a human taps. Nothing here can start an evening, and Bluetooth
/// being off, unavailable or refused makes no difference to anything else
/// (rule 7).
@MainActor
public final class NearbyScanner: NSObject {

    private var manager: CBCentralManager?
    private var found: (@MainActor (String) -> Void)?
    /// Held while connected, because Core Bluetooth doesn't, and a released
    /// peripheral disconnects mid-read.
    private var connected: [UUID: CBPeripheral] = [:]
    /// One read per phone per run. The same table is rediscovered every few
    /// seconds and connecting again would tell us what we already know.
    private var read: Set<UUID> = []

    public override init() { super.init() }

    /// Starts only if the person has already been asked — at the dock, by
    /// `NearbyBeacon`. Until then this does nothing at all, so the first
    /// Bluetooth prompt can't land on someone who has just signed in and has
    /// no idea yet what any of this is for.
    /// Called again on every return to the foreground, which is the point:
    /// iOS stops a scan while the app is suspended, and this is what picks it
    /// back up.
    public func start(_ found: @escaping @MainActor (String) -> Void) {
        guard NearbyBeacon.wasAsked else { return }
        self.found = found
        guard let manager else {
            manager = CBCentralManager(delegate: self, queue: nil)
            return
        }
        scan(manager)
    }

    public func stop() {
        found = nil
        read = []
        if let manager {
            if manager.isScanning { manager.stopScan() }
            for peripheral in connected.values { manager.cancelPeripheralConnection(peripheral) }
        }
        connected = [:]
        manager = nil
    }

    private func scan(_ manager: CBCentralManager) {
        guard manager.state == .poweredOn, !manager.isScanning else { return }
        // Filtering by service id is not only politeness: a backgrounded
        // advertiser's id sits in the overflow area, where an unfiltered scan
        // cannot see it at all.
        manager.scanForPeripherals(withServices: [CBUUID(string: Nearby.service)],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func done(with peripheral: CBPeripheral) {
        manager?.cancelPeripheralConnection(peripheral)
        connected[peripheral.identifier] = nil
    }
}

extension NearbyScanner: CBCentralManagerDelegate {

    nonisolated public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        Task { @MainActor in self.scan(manager) }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didDiscover peripheral: CBPeripheral,
                                           advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard !self.read.contains(peripheral.identifier),
                  self.connected[peripheral.identifier] == nil else { return }
            peripheral.delegate = self
            self.connected[peripheral.identifier] = peripheral
            manager.connect(peripheral)
        }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: Nearby.service)])
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in self.connected[peripheral.identifier] = nil }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in self.connected[peripheral.identifier] = nil }
    }
}

extension NearbyScanner: CBPeripheralDelegate {

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first else {
            Task { @MainActor in self.done(with: peripheral) }
            return
        }
        peripheral.discoverCharacteristics([CBUUID(string: Nearby.characteristic)], for: service)
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral,
                                       didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristic = service.characteristics?.first else {
            Task { @MainActor in self.done(with: peripheral) }
            return
        }
        peripheral.readValue(for: characteristic)
    }

    /// The key, or something a stranger's device answered with. `Nearby.key`
    /// decides which, and only the former becomes a question.
    nonisolated public func peripheral(_ peripheral: CBPeripheral,
                                       didUpdateValueFor characteristic: CBCharacteristic,
                                       error: Error?) {
        let key = error == nil ? Nearby.key(from: characteristic.value) : nil
        Task { @MainActor in
            self.read.insert(peripheral.identifier)
            self.done(with: peripheral)
            if let key { self.found?(key) }
        }
    }
}
