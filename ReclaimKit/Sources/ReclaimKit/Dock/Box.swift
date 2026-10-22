import Foundation
import CryptoKit

/// The box over Bluetooth: how it says a slot filled, and how a phone decides
/// whether that was it.
///
/// The box is a peripheral with one service and two characteristics. `id` is
/// who it is; `slots` is one byte, a bit per slot, sent to every phone
/// connected to it the moment a sensor changes. The box lights its own slots
/// from those sensors — the phone only has to work out whether it is the one
/// that just went in.
///
/// Plain values, so every decision here is tested without a radio.
public enum Box {

    public static let service = "3F1C5B2E-8D4A-4E6B-9C2F-0A7D1E5B8C40"
    /// Eight bytes: the start of SHA-256 of the box's secret. Enough to tell
    /// two boxes apart; useless for joining anything. The secret itself never
    /// goes over the air.
    public static let idCharacteristic = "3F1C5B2E-8D4A-4E6B-9C2F-0A7D1E5B8C41"
    /// One byte, bit 0 for slot 1. Readable, and notifies on every change.
    public static let slotsCharacteristic = "3F1C5B2E-8D4A-4E6B-9C2F-0A7D1E5B8C42"

    /// What the box's firmware is flashed with (`scripts/dock-tags.sh` prints
    /// it beside the tag links), and what the phone compares against when it
    /// pairs.
    public static func id(secret: String) -> Data {
        Data(SHA256.hash(data: Data(secret.utf8)).prefix(8))
    }

    /// Which slots are full.
    public struct Slots: Equatable, Sendable {
        public let bits: UInt8

        public init(bits: UInt8) { self.bits = bits }

        public init?(_ data: Data?) {
            guard let data, data.count == 1 else { return nil }
            bits = data[data.startIndex]
        }

        public var full: Set<Int> {
            Set(Dock.slots.filter { bits & (1 << ($0 - 1)) != 0 })
        }

        /// Slots full now that weren't before.
        public func filled(since earlier: Slots) -> Set<Int> { full.subtracting(earlier.full) }
        /// Slots empty now that were full before.
        public func emptied(since earlier: Slots) -> Set<Int> { earlier.full.subtracting(full) }
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

    /// A slot emptied, and this phone was in the box. If it's still charging,
    /// it was somebody else's.
    public static func hasLeft(docked: Bool, charging: Bool) -> Bool {
        docked && !charging
    }
}
