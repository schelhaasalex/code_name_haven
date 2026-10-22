import Foundation

/// The one box this phone belongs to: which radio it is, and which place.
///
/// Learned once, from the first tag read in it, and kept on this phone only.
/// A phone set into a different box's slot re-learns — the newest box wins,
/// because the box this phone was put in most recently is the one it lives in.
public struct BoxPairing: Codable, Equatable, Sendable {
    /// Core Bluetooth's name for the box on this phone. Not the box's own id:
    /// iOS gives every phone a different one for the same device.
    public let peripheral: UUID
    public let place: UUID
    public let id: Data

    public init(peripheral: UUID, place: UUID, id: Data) {
        self.peripheral = peripheral; self.place = place; self.id = id
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
