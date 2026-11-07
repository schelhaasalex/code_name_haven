import Foundation
import CoreBluetooth

/// The phone's standing connection to each of its boxes.
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

    /// One of this phone's boxes changed: which radio, what its slots are
    /// now, what they were, and how close it is. The signal strength is nil
    /// when it couldn't be read.
    public typealias Changed = @MainActor (_ box: UUID, _ now: Box.Slots, _ before: Box.Slots, _ rssi: Int?) -> Void

    private static let restoreID = "reclaim.box"
    /// How long pairing listens before taking the closest dock, and how long
    /// it waits for one at all.
    private static let listen: Duration = .seconds(3)
    private static let giveUp: Duration = .seconds(12)

    private var manager: CBCentralManager?
    /// Every box this phone holds a connection to, by Core Bluetooth's id.
    private var boxes: [UUID: CBPeripheral] = [:]
    private var slots: [UUID: Box.Slots] = [:]
    private var changed: Changed?
    /// A slot change waiting on its signal strength, per box.
    private var pending: [UUID: Box.Slots] = [:]

    /// Pairing: what it calls back with, the radios it mustn't take (the
    /// phone's other boxes), and every dock heard meanwhile.
    private var paired: (@MainActor (UUID?) -> Void)?
    private var except: Set<UUID> = []
    private var heard: [UUID: Int] = [:]
    private var candidates: [UUID: CBPeripheral] = [:]

    public override init() { super.init() }

    /// At every launch — background ones included, which is when it matters.
    public func resume(_ changed: @escaping Changed) {
        self.changed = changed
        guard !BoxPairing.peripherals.isEmpty else { return }
        start()
    }

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

    /// A box this phone no longer belongs to, or a radio its box replaced.
    public func letGo(of peripheral: UUID) {
        guard let box = boxes.removeValue(forKey: peripheral) else { return }
        slots[peripheral] = nil
        pending[peripheral] = nil
        manager?.cancelPeripheralConnection(box)
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
        let missing = BoxPairing.peripherals.filter { boxes[$0] == nil }
        for found in manager.retrievePeripherals(withIdentifiers: missing) { hold(found, with: manager) }
    }

    /// Never times out — that is the point of it.
    private func hold(_ peripheral: CBPeripheral, with manager: CBCentralManager) {
        boxes[peripheral.identifier] = peripheral
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
            slots[peripheral.identifier] = Box.Slots(bits: 0)
            hold(peripheral, with: manager)
        }
        done(peripheral?.identifier)
    }

    /// A value off a box: its slots, or one of its events. Both say the
    /// same change, and whichever arrives first is the one acted on.
    func read(_ characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        guard boxes[peripheral.identifier] === peripheral else { return }
        let id = peripheral.identifier
        switch characteristic.uuid {
        case CBUUID(string: Box.slotStateCharacteristic):
            if let now = Box.Slots(state: characteristic.value) { apply(now, from: peripheral) }
        case CBUUID(string: Box.eventCharacteristic):
            if let event = Box.Event(characteristic.value) {
                apply((pending[id] ?? slots[id] ?? Box.Slots(bits: 0)).after(event), from: peripheral)
            }
        default:
            break
        }
    }

    private func apply(_ now: Box.Slots, from peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard now != (pending[id] ?? slots[id] ?? Box.Slots(bits: 0)) else { return }
        let measuring = pending[id] != nil
        pending[id] = now
        if !measuring { peripheral.readRSSI() }
    }

    func measured(_ rssi: Int?, of peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard let now = pending.removeValue(forKey: id) else { return }
        let before = slots[id] ?? Box.Slots(bits: 0)
        slots[id] = now
        changed?(id, now, before, rssi)
    }

    func connected(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: Box.service)])
    }

    func discovered(_ service: CBService, of peripheral: CBPeripheral) {
        guard boxes[peripheral.identifier] === peripheral else { return }
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
        // Wait for it to come back.
        if boxes[peripheral.identifier] === peripheral, let manager { manager.connect(peripheral) }
    }

    func discoveredCandidate(_ peripheral: CBPeripheral, rssi: Int) {
        // 127 is Core Bluetooth's "couldn't measure".
        guard paired != nil, rssi != 127 else { return }
        candidates[peripheral.identifier] = peripheral
        heard[peripheral.identifier] = max(rssi, heard[peripheral.identifier] ?? .min)
    }

    func restored(_ peripherals: [CBPeripheral]) {
        let known = Set(BoxPairing.peripherals)
        for found in peripherals where known.contains(found.identifier) {
            boxes[found.identifier] = found
            found.delegate = self
        }
    }

    func stateChanged(_ manager: CBCentralManager) { ready(manager) }
}
