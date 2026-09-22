import Foundation
import CoreBluetooth

/// The phone that is already down, saying so — to the table, and to nobody
/// else.
///
/// It advertises in the BACKGROUND, because that is where this phone is: face
/// down, screen off, an hour into dinner. iOS strips the local name and every
/// byte of service data from a backgrounded advertisement and puts the service
/// id in an overflow area only a central explicitly asking for that id can
/// see — which is why the key is handed over on connect instead of broadcast,
/// and why the advertisement itself says nothing but "one of these is here".
///
/// The key comes from `app.open_nearby()`, which refuses an evening at no
/// place. Nothing is gated on any of this: Bluetooth off, permission declined,
/// no hardware at all, and the evening runs exactly as it would have (rule 7).
///
/// This is also where the Bluetooth prompt happens, the first time — the
/// moment after a person has set their phone down, which is the only moment
/// where "so the phones around you can find this table" means anything.
@MainActor
public final class NearbyBeacon: NSObject {

    private var manager: CBPeripheralManager?
    private var key: String?
    /// The service is on the manager, and `add` is out waiting for its
    /// callback. Two flags rather than one because advertising can't begin
    /// until the service is really there, and adding it twice fails.
    private var added = false
    private var adding = false

    public override init() { super.init() }

    /// Start, or hand out a new key for an evening that moved.
    public func start(key: String) {
        self.key = key
        guard let manager else {
            // Created only now, not at launch: this is what asks.
            manager = CBPeripheralManager(delegate: self, queue: nil)
            return
        }
        if manager.state == .poweredOn, !manager.isAdvertising { advertise(manager) }
    }

    public func stop() {
        key = nil
        added = false
        adding = false
        guard let manager else { return }
        if manager.isAdvertising { manager.stopAdvertising() }
        manager.removeAllServices()
        self.manager = nil
    }

    /// Whether the person has been asked yet. The scanner waits for this, so
    /// that the question arrives at the dock rather than at the first launch.
    public static var wasAsked: Bool {
        CBManager.authorization != .notDetermined
    }

    private func advertise(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn, key != nil else { return }
        guard added else {
            guard !adding else { return }
            adding = true
            let characteristic = CBMutableCharacteristic(
                type: CBUUID(string: Nearby.characteristic),
                properties: [.read], value: nil, permissions: [.readable])
            let service = CBMutableService(type: CBUUID(string: Nearby.service), primary: true)
            service.characteristics = [characteristic]
            manager.add(service)   // advertising waits for didAdd
            return
        }
        guard !manager.isAdvertising else { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: Nearby.service)]
        ])
    }
}

extension NearbyBeacon: CBPeripheralManagerDelegate {

    /// Bluetooth off, or turned off mid-evening, or never allowed: silence.
    /// There is nothing to tell a person here — they are having dinner.
    nonisolated public func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        Task { @MainActor in
            guard manager.state == .poweredOn else { return }
            // Bluetooth off and back on drops the services with it, so this
            // starts from nothing rather than from what it last believed.
            manager.removeAllServices()
            self.added = false
            self.adding = false
            self.advertise(manager)
        }
    }

    nonisolated public func peripheralManager(_ manager: CBPeripheralManager,
                                              didAdd service: CBService, error: Error?) {
        Task { @MainActor in
            self.adding = false
            self.added = error == nil
            self.advertise(manager)
        }
    }

    /// Somebody connected and asked. This is the only thing that ever leaves
    /// this phone over the radio.
    nonisolated public func peripheralManager(_ manager: CBPeripheralManager,
                                              didReceiveRead request: CBATTRequest) {
        Task { @MainActor in
            guard let key = self.key else {
                manager.respond(to: request, withResult: .readNotPermitted)
                return
            }
            let data = Nearby.data(for: key)
            guard request.offset <= data.count else {
                manager.respond(to: request, withResult: .invalidOffset)
                return
            }
            request.value = data.subdata(in: request.offset ..< data.count)
            manager.respond(to: request, withResult: .success)
        }
    }
}
