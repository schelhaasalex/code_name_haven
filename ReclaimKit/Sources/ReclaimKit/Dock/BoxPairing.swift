import Foundation

/// The one box this phone belongs to: which place it is, and which radio.
///
/// The place is learned the moment the box's tag or code is read; the radio a
/// few seconds later — the dock the phone is closest to right then — and only
/// if Bluetooth is there to find it. Without one the box is still this
/// phone's, and its tags still work.
///
/// Kept on this phone only. Reading another box's re-learns: the newest box
/// wins, because the box this phone was put in most recently is the one it
/// lives in. (A pairing saved by an earlier version also carried the box's
/// id; it decodes the same without it.)
public struct BoxPairing: Codable, Equatable, Sendable {
    public let place: UUID
    /// Core Bluetooth's name for the box on this phone. Not the box's own id:
    /// iOS gives every phone a different one for the same device.
    public var peripheral: UUID?

    public init(place: UUID, peripheral: UUID? = nil) {
        self.place = place; self.peripheral = peripheral
    }

    private static let key = "dock.box"

    public static var current: BoxPairing? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(BoxPairing.self, from: data)
        }
        set {
            UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
        }
    }
}
