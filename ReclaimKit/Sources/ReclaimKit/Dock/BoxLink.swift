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
/// won't relaunch it for Bluetooth until the app is next opened.
///
/// No box paired, no radio: the manager is only created once there is a box
/// to talk to, so nobody without one is ever asked about Bluetooth for it.
@MainActor
public final class BoxLink: NSObject {

    /// The box's slots changed: what they are now, what they were, and how
    /// close the box is. The signal strength is nil when it couldn't be read.
    public typealias Changed = @MainActor (_ now: Box.Slots, _ before: Box.Slots, _ rssi: Int?) -> Void

    private static let restoreID = "reclaim.box"
    /// How long pairing listens before taking the closest dock, and how long
    /// it waits for one at all.
    private static let listen: Duration = .seconds(3)
    private static let giveUp: Duration = .seconds(12)

    private var manager: CBCentralManager?
    private var box: CBPeripheral?
    private var slots = Box.Slots(bits: 0)
    private var changed: Changed?
    /// A slot change waiting on its signal strength.
    private var pending: Box.Slots?

    /// Pairing: what it calls back with, and every dock heard meanwhile.
    private var paired: (@MainActor (UUID?) -> Void)?
    private var heard: [UUID: Int] = [:]
    private var candidates: [UUID: CBPeripheral] = [:]

    public override init() { super.init() }

    /// At every launch — background ones included, which is when it matters.
    public func resume(_ changed: @escaping Changed) {
        self.changed = changed
        guard BoxPairing.current != nil else { return }
        start()
    }

    /// Keeps the dock this phone is closest to. Called the moment a box's tag
    /// or code is read, in the foreground and at the box — so a box that
    /// can't be heard (no radio yet, Bluetooth off) is simply not paired.
    public func pair(then done: @escaping @MainActor (UUID?) -> Void) {
        paired = done
        heard = [:]
        start()
        Task { @MainActor [weak self] in
            let began = ContinuousClock.now
            while ContinuousClock.now - began < Self.giveUp {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.paired != nil else { return }
                if ContinuousClock.now - began >= Self.listen, let closest = Box.closest(self.heard) {
                    self.finishPairing(self.candidates[closest])
                    return
                }
            }
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
        if paired != nil, !manager.isScanning {
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
        guard let done = paired else { return }
        paired = nil
        manager?.stopScan()
        heard = [:]
        candidates = [:]
        if let peripheral, let manager {
            if let old = box, old !== peripheral { manager.cancelPeripheralConnection(old) }
            box = nil
            slots = Box.Slots(bits: 0)
            hold(peripheral, with: manager)
        }
        done(peripheral?.identifier)
    }

    /// A value off the box: its slots, or one of its events. Both say the
    /// same change, and whichever arrives first is the one acted on.
    func read(_ characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        guard peripheral === box else { return }
        switch characteristic.uuid {
        case CBUUID(string: Box.slotStateCharacteristic):
            if let now = Box.Slots(state: characteristic.value) { apply(now, from: peripheral) }
        case CBUUID(string: Box.eventCharacteristic):
            if let event = Box.Event(characteristic.value) {
                apply((pending ?? slots).after(event), from: peripheral)
            }
        default:
            break
        }
    }

    private func apply(_ now: Box.Slots, from peripheral: CBPeripheral) {
        guard now != (pending ?? slots) else { return }
        let measuring = pending != nil
        pending = now
        if !measuring { peripheral.readRSSI() }
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
        guard peripheral === box else { return }
        peripheral.discoverCharacteristics(
            [Box.slotStateCharacteristic, Box.eventCharacteristic, Box.commandCharacteristic].map(CBUUID.init),
            for: service)
    }

    /// Subscribe to the slots and the events, read the slots once to catch
    /// up, and tell the dock the time.
    func found(_ characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case CBUUID(string: Box.slotStateCharacteristic):
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)
        case CBUUID(string: Box.eventCharacteristic):
            peripheral.setNotifyValue(true, for: characteristic)
        case CBUUID(string: Box.commandCharacteristic):
            let type: CBCharacteristicWriteType =
                characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
            peripheral.writeValue(Box.timeCommand(), for: characteristic, type: type)
        default:
            break
        }
    }

    func lost(_ peripheral: CBPeripheral) {
        if peripheral === box, let manager { manager.connect(peripheral) }   // wait for it to come back
    }

    func discoveredCandidate(_ peripheral: CBPeripheral, rssi: Int) {
        // 127 is Core Bluetooth's "couldn't measure".
        guard paired != nil, rssi != 127 else { return }
        candidates[peripheral.identifier] = peripheral
        heard[peripheral.identifier] = max(rssi, heard[peripheral.identifier] ?? .min)
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
