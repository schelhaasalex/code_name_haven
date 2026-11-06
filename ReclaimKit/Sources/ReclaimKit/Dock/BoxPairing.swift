import Foundation

/// The one box this phone belongs to: which radio it is, and which place.
///
/// Learned once — the closest dock when the box's tag or code was read — and
/// kept on this phone only. Reading another box's re-learns: the newest box
/// wins, because the box this phone was put in most recently is the one it
/// lives in. (A pairing saved by an earlier version also carried the box's id;
/// it decodes the same without it.)
public struct BoxPairing: Codable, Equatable, Sendable {
    /// Core Bluetooth's name for the box on this phone. Not the box's own id:
    /// iOS gives every phone a different one for the same device.
    public let peripheral: UUID
    public let place: UUID

    public init(peripheral: UUID, place: UUID) {
        self.peripheral = peripheral; self.place = place
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
