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

    /// The box about itself, a moment after a phone tells it the time: how
    /// many times it has started, how long this run has lasted, why it began
    /// (ESP-IDF's reset reason), and its firmware.
    public struct Hello: Decodable, Equatable, Sendable {
        public let boots: Int
        public let up: Int
        public let reset: Int?
        public let fw: String?

        public init?(_ data: Data?) {
            struct Kind: Decodable { let v: Int; let event: String }
            guard let data, let kind = try? JSONDecoder().decode(Kind.self, from: data),
                  kind.v == 1, kind.event == "hello",
                  let hello = try? JSONDecoder().decode(Hello.self, from: data) else { return nil }
            self = hello
        }

        /// As a note's detail.
        public var detail: [String: String] {
            var d = ["boots": "\(boots)", "up": "\(up)"]
            if let reset { d["reset"] = "\(reset)" }
            if let fw { d["fw"] = fw }
            return d
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

    /// The strongest dock heard while pairing, if any was close enough —
    /// leaving out the radios of this phone's other boxes. With the kitchen's
    /// box already paired, the bedroom's card read in the doorway between them
    /// finds the bedroom's, even if the kitchen's is louder.
    public static func closest(_ heard: [UUID: Int], except known: Set<UUID> = []) -> UUID? {
        heard.filter { $0.value >= pairable && !known.contains($0.key) }.max { $0.value < $1.value }?.key
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
    ///
    /// "Already charging" is only as good as the app's watching. iOS tells
    /// only a running app about the battery, so a phone seen charging last
    /// night, unplugged while the app slept and put in the box this morning
    /// looked like it had never stopped — and nothing happened. When the app
    /// slept through part of the stretch (`unbroken` false), the phone's
    /// closeness decides instead, and has to be read to count.
    public static func isThisPhone(charging: Bool, wasCharging: Bool, unbroken: Bool = true,
                                   rssi: Int?) -> Bool {
        guard charging else { return false }
        if wasCharging {
            guard !unbroken, let rssi else { return false }
            return rssi >= nearby
        }
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
    /// ends, counted down on the lock screen and in the app. Long enough for
    /// one that slipped off the pad, or was moved to the next slot; not long
    /// enough to check a message. Fifteen felt like the app hadn't noticed.
    public static let outGrace: TimeInterval = 5

    /// A slot emptied `outGrace` ago, and this phone was in the box. If it's
    /// charging, it was somebody else's — or this one, back already.
    public static func hasLeft(docked: Bool, charging: Bool) -> Bool {
        docked && !charging
    }
}
