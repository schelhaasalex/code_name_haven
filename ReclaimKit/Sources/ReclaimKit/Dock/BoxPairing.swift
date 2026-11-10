import Foundation

/// A box this phone belongs to: which place it is, and which radio.
///
/// The place is learned the moment the box's card is read; the radio
/// a few seconds later — the closest dock the phone doesn't already know —
/// and only if Bluetooth is there to find it. Without one the box is still
/// this phone's, but nothing starts an evening there until its radio is
/// heard: its page in Settings offers to scan the card again.
///
/// A phone can belong to several boxes — the kitchen's and the bedroom's —
/// and holds a connection to each, so whichever one it's put in starts the
/// evening there. Kept on this phone only, in the order they were met.
public struct BoxPairing: Codable, Equatable, Sendable {
    public let place: UUID
    /// Core Bluetooth's name for the box on this phone. Not the box's own id:
    /// iOS gives every phone a different one for the same device.
    public var peripheral: UUID?

    public init(place: UUID, peripheral: UUID? = nil) {
        self.place = place; self.peripheral = peripheral
    }

    private static let key = "dock.boxes"
    /// Where the one box lived before there could be several.
    private static let oneKey = "dock.box"

    /// Every box, oldest first.
    public static var all: [BoxPairing] {
        get {
            let defaults = UserDefaults.standard
            if let data = defaults.data(forKey: key) {
                return (try? JSONDecoder().decode([BoxPairing].self, from: data)) ?? []
            }
            guard let data = defaults.data(forKey: oneKey),
                  let one = try? JSONDecoder().decode(BoxPairing.self, from: data)
            else { return [] }
            return [one]
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key)
            UserDefaults.standard.removeObject(forKey: oneKey)
        }
    }

    /// Met, or met again: the place joins the list if it's new, keeping the
    /// radio it had unless a new one is given.
    public static func met(_ place: UUID, peripheral: UUID? = nil) {
        var boxes = all
        if let i = boxes.firstIndex(where: { $0.place == place }) {
            if let peripheral { boxes[i].peripheral = peripheral }
        } else {
            boxes.append(BoxPairing(place: place, peripheral: peripheral))
        }
        // One radio is one box: a radio heard for this place is no other's.
        if let peripheral {
            for i in boxes.indices where boxes[i].place != place && boxes[i].peripheral == peripheral {
                boxes[i].peripheral = nil
            }
        }
        all = boxes
    }

    public static func forget(_ place: UUID) {
        all = all.filter { $0.place != place }
    }

    /// The box whose radio this is.
    public static func place(of peripheral: UUID) -> UUID? {
        all.first { $0.peripheral == peripheral }?.place
    }

    public static var peripherals: [UUID] { all.compactMap(\.peripheral) }
}
