import Foundation
import CoreBluetooth

/// Core Bluetooth's callbacks, each handed straight back to the main actor,
/// where `BoxLink` keeps all of its state.
extension BoxLink: CBCentralManagerDelegate {

    nonisolated public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        Task { @MainActor in self.stateChanged(manager) }
    }

    /// The app was relaunched in the background for the box. The connection
    /// iOS kept open is in here, and has to be claimed before anything else.
    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           willRestoreState state: [String: Any]) {
        let peripherals = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        Task { @MainActor in self.restored(peripherals) }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didDiscover peripheral: CBPeripheral,
                                           advertisementData: [String: Any], rssi: NSNumber) {
        let strength = rssi.intValue
        // The box's name is in its scan response; iOS hands it over here, and
        // keeps it as the peripheral's name once it has seen one.
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        Task { @MainActor in self.discoveredCandidate(peripheral, rssi: strength, name: name) }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didConnect peripheral: CBPeripheral) {
        Task { @MainActor in self.connected(peripheral) }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in self.lost(peripheral) }
    }

    nonisolated public func centralManager(_ manager: CBCentralManager,
                                           didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in self.lost(peripheral) }
    }
}

extension BoxLink: CBPeripheralDelegate {

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == CBUUID(string: Box.service) })
        else { return }
        Task { @MainActor in self.discovered(service, of: peripheral) }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral,
                                       didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            Task { @MainActor in self.found(characteristic, of: peripheral) }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral,
                                       didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else { return }
        Task { @MainActor in self.read(characteristic, of: peripheral) }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let rssi = error == nil ? RSSI.intValue : nil
        Task { @MainActor in self.measured(rssi, of: peripheral) }
    }
}
