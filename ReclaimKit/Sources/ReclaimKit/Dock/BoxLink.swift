import Foundation
import CoreBluetooth

/// The phone's standing connection to its box.
///
/// Core Bluetooth will hold a connection request open forever and complete it
/// whenever the box is in range — waking the app in the background to do so,
/// and relaunching it if the system had closed it. Once connected, every
/// change the box notifies wakes the app again for a few seconds. That is the
/// whole trick: a phone set into the box has its app running before the
/// drawer is shut, with nobody touching anything.
///
/// The one thing that defeats it is the person swiping the app away. Then iOS
/// won't relaunch it for Bluetooth, and the slot's tag is the way in (rule 7).
///
/// No box paired, no radio: the manager is only created once there is a box
/// to talk to, so nobody without one is ever asked about Bluetooth for it.
@MainActor
public final class BoxLink: NSObject {

    /// The box's slots changed: what they are now, what they were, and how
    /// close the box is. The signal strength is nil when it couldn't be read.
    public typealias Changed = @MainActor (_ now: Box.Slots, _ before: Box.Slots, _ rssi: Int?) -> Void

    private static let restoreID = "reclaim.box"

    private var manager: CBCentralManager?
    private var box: CBPeripheral?
    private var slots = Box.Slots(bits: 0)
    private var changed: Changed?
    /// A slot change waiting on its signal strength.
    private var pending: Box.Slots?

    /// Pairing: the id being looked for, what it calls back with, and the
    /// candidates connected to while their ids are read.
    private var seeking: Data?
    private var paired: (@MainActor (UUID?) -> Void)?
    private var candidates: [UUID: CBPeripheral] = [:]

    public override init() { super.init() }

    /// At every launch — background ones included, which is when it matters.
    public func resume(_ changed: @escaping Changed) {
        self.changed = changed
        guard BoxPairing.current != nil else { return }
        start()
    }

    /// Finds the box whose id this is, among the boxes in range, and keeps it.
    /// Called with the tag's secret in hand, in the foreground, so a box that
    /// can't be found (no radio yet, Bluetooth off) is simply not paired.
    public func pair(id: Data, then done: @escaping @MainActor (UUID?) -> Void) {
        seeking = id
        paired = done
        start()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            self?.finishPairing(nil)
        }
    }

    private func start() {
        guard let manager else {
            manager = CBCentralManager(delegate: self, queue: nil,
                                       options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreID])
            return
        }
        ready(manager)
    }

    private func ready(_ manager: CBCentralManager) {
        guard manager.state == .poweredOn else { return }
        if seeking != nil, !manager.isScanning {
            manager.scanForPeripherals(withServices: [CBUUID(string: Box.service)])
        }
        guard box == nil, let pairing = BoxPairing.current,
              let found = manager.retrievePeripherals(withIdentifiers: [pairing.peripheral]).first
        else { return }
        hold(found, with: manager)
    }

    /// Never times out — that is the point of it.
    private func hold(_ peripheral: CBPeripheral, with manager: CBCentralManager) {
        box = peripheral
        peripheral.delegate = self
        if peripheral.state != .connected { manager.connect(peripheral) }
        else { peripheral.discoverServices([CBUUID(string: Box.service)]) }
    }

    private func finishPairing(_ peripheral: CBPeripheral?) {
        guard seeking != nil else { return }
        seeking = nil
        manager?.stopScan()
        for candidate in candidates.values where candidate !== peripheral {
            manager?.cancelPeripheralConnection(candidate)
        }
        candidates = [:]
        if let peripheral, let manager {
            if let old = box, old !== peripheral { manager.cancelPeripheralConnection(old) }
            box = nil
            hold(peripheral, with: manager)
        }
        let done = paired
        paired = nil
        done?(peripheral?.identifier)
    }

    /// A value off the box. Its id, while pairing; its slots, the rest of the time.
    func read(_ characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case CBUUID(string: Box.idCharacteristic):
            guard let seeking, characteristic.value == seeking else {
                if candidates[peripheral.identifier] != nil { manager?.cancelPeripheralConnection(peripheral) }
                candidates[peripheral.identifier] = nil
                return
            }
            candidates[peripheral.identifier] = nil
            finishPairing(peripheral)
        case CBUUID(string: Box.slotsCharacteristic):
            guard peripheral === box, let now = Box.Slots(characteristic.value), now != slots else { return }
            pending = now
            peripheral.readRSSI()
        default:
            break
        }
    }

    func measured(_ rssi: Int?) {
        guard let now = pending else { return }
        pending = nil
        let before = slots
        slots = now
        changed?(now, before, rssi)
    }

    func connected(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: Box.service)])
    }

    func discovered(_ service: CBService, of peripheral: CBPeripheral) {
        // A candidate only needs its id; the box, its slots.
        let wanted = peripheral === box ? Box.slotsCharacteristic : Box.idCharacteristic
        peripheral.discoverCharacteristics([CBUUID(string: wanted)], for: service)
    }

    func found(_ characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        if characteristic.uuid == CBUUID(string: Box.slotsCharacteristic) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
        peripheral.readValue(for: characteristic)
    }

    func lost(_ peripheral: CBPeripheral) {
        if peripheral === box, let manager { manager.connect(peripheral) }   // wait for it to come back
        candidates[peripheral.identifier] = nil
    }

    func discoveredCandidate(_ peripheral: CBPeripheral) {
        guard seeking != nil, candidates[peripheral.identifier] == nil, peripheral !== box else { return }
        candidates[peripheral.identifier] = peripheral
        peripheral.delegate = self
        manager?.connect(peripheral)
    }

    func restored(_ peripherals: [CBPeripheral]) {
        guard let pairing = BoxPairing.current,
              let found = peripherals.first(where: { $0.identifier == pairing.peripheral })
        else { return }
        box = found
        found.delegate = self
    }

    func stateChanged(_ manager: CBCentralManager) { ready(manager) }
}
