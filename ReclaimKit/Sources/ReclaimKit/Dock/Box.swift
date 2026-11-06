import Foundation

/// The box over Bluetooth — the Portside dock protocol, version 1 — and how a
/// phone decides whether a slot that filled was it.
///
/// The dock is a peripheral with one service. `slotState` is a byte per slot
/// (empty, charging, full), read on connect and notified on every change;
/// `event` says the same thing as one JSON message per change; `command` takes
/// the app's JSON. The dock lights its own slots from its own sensors — the
/// phone only has to work out whether it is the one that just went in.
///
/// The ids are the dock's, and may change before production; they live here
/// and in `firmware/box/box.ino`, nowhere else.
///
/// Plain values, so every decision here is tested without a radio.
public enum Box {

    public static let service = "6E400001-B5A3-F393-E0A9-0000706F7274"
    /// A byte per slot, slot 1 first: 0 empty, 1 charging, 2 full.
    public static let slotStateCharacteristic = "6E400010-B5A3-F393-E0A9-0000706F7274"
    /// One JSON object per change: `{"v":1,"slot":1,"event":"docked",…}`.
    public static let eventCharacteristic = "6E400011-B5A3-F393-E0A9-0000706F7274"
    /// JSON from the app: the time, a light, a ping.
    public static let commandCharacteristic = "6E400020-B5A3-F393-E0A9-0000706F7274"

    /// Which slots have a phone in them. Charging and full are both a phone.
    public struct Slots: Equatable, Sendable {
        public let bits: UInt8

        public init(bits: UInt8) { self.bits = bits }

        public init(full: Set<Int>) {
            bits = full.filter(Dock.slots.contains).reduce(0) { $0 | UInt8(1 << ($1 - 1)) }
        }

        /// The dock's slot state: one byte per slot. A dock with fewer slots
        /// sends fewer bytes; more than the box has is not a slot state.
        public init?(state data: Data?) {
            guard let data, (1...Dock.slots.count).contains(data.count) else { return nil }
            self.init(full: Set(data.enumerated().filter { $0.element != 0 }.map { $0.offset + 1 }))
        }

        public var full: Set<Int> {
            Set(Dock.slots.filter { bits & (1 << ($0 - 1)) != 0 })
        }

        /// Slots full now that weren't before.
        public func filled(since earlier: Slots) -> Set<Int> { full.subtracting(earlier.full) }
        /// Slots empty now that were full before.
        public func emptied(since earlier: Slots) -> Set<Int> { earlier.full.subtracting(full) }

        /// What the slots are after one of the dock's events. "full" and
        /// "pong" change nothing: a phone that stopped drawing much is still in.
        public func after(_ event: Event) -> Slots {
            guard let slot = event.slot, Dock.slots.contains(slot) else { return self }
            switch event.kind {
            case "docked":   return Slots(full: full.union([slot]))
            case "undocked": return Slots(full: full.subtracting([slot]))
            default:         return self
            }
        }
    }

    /// One message off `event`. Only what the phone acts on; the dock also
    /// sends its time and the pad's current, which nothing here needs.
    public struct Event: Decodable, Equatable, Sendable {
        public let v: Int
        public let slot: Int?
        public let kind: String

        enum CodingKeys: String, CodingKey { case v, slot, kind = "event" }

        public init(v: Int = 1, slot: Int?, kind: String) { self.v = v; self.slot = slot; self.kind = kind }

        /// A version this phone doesn't know is not read as one it does.
        public init?(_ data: Data?) {
            guard let data, let e = try? JSONDecoder().decode(Event.self, from: data), e.v == 1 else { return nil }
            self = e
        }
    }

    /// Sent on every connect, so the times in the dock's events are real dates.
    public static func timeCommand(at date: Date = .now) -> Data {
        Data(#"{"cmd":"time","epoch":\#(Int(date.timeIntervalSince1970))}"#.utf8)
    }

    /// While pairing, the dock the phone is closest to is the one it's at:
    /// the tag was just read in its slot, or its code scanned from a hand's
    /// length away. Weaker than this is a dock across the room, or next door.
    public static let pairable = -75

    /// The strongest dock heard while pairing, if any was close enough.
    public static func closest(_ heard: [UUID: Int]) -> UUID? {
        heard.filter { $0.value >= pairable }.max { $0.value < $1.value }?.key
    }

    /// Closer than this, and the phone is in the box rather than in the room.
    /// A phone lying on the box's own antenna reads around -30 to -50; one
    /// across the room, -70 and below.
    public static let nearby = -60

    /// A slot just filled. Was it this phone?
    ///
    /// Every phone connected to the box hears every slot fill, so the answer
    /// has to come from the phone itself: it has just started charging — it
    /// wasn't, the last time it looked — and the box is right there. A phone
    /// already charging on the bedside table hasn't just started; one in a
    /// pocket isn't charging at all; one on a charger in the next room is too
    /// far away.
    ///
    /// An unknown signal strength doesn't count against it: charging that
    /// began in the same breath as a slot filling is most of the evidence.
    public static func isThisPhone(charging: Bool, wasCharging: Bool, rssi: Int?) -> Bool {
        guard charging, !wasCharging else { return false }
        guard let rssi else { return true }
        return rssi >= nearby
    }

    /// Whether charging that began at `since` is news at `at`. Charging this
    /// phone was already doing half a minute before a slot filled was some
    /// other charger's doing, not the box's.
    public static func justStarted(chargingSince since: Date?, at: Date, window: TimeInterval = 30) -> Bool {
        guard let since else { return false }
        return at.timeIntervalSince(since) <= window
    }

    /// How long a phone that came out has to go back in before its evening
    /// ends. Long enough for one that slipped off the pad, or was moved to the
    /// next slot; not long enough to check a message. Inside the half minute
    /// iOS gives a Bluetooth wake, with room left to tell the server.
    public static let outGrace: TimeInterval = 15

    /// A slot emptied `outGrace` ago, and this phone was in the box. If it's
    /// charging, it was somebody else's — or this one, back already.
    public static func hasLeft(docked: Bool, charging: Bool) -> Bool {
        docked && !charging
    }
}
