import Foundation

/// The box: four slots in a drawer, each with a tag under where the top of a
/// phone lands, and a light on the outside for each.
///
/// A slot's tag carries `https://<domain>/d/<secret>/<slot>`. The secret is
/// the box's, the same on all four, and it is a place's join secret like a
/// card's — except written before anyone owned the box, so the first phone
/// set into it is the one that makes its place (`dock_place`, migration 0013).
///
/// `/d/`, never `/p/`. An unknown card is a mistake to say out loud; an unknown
/// box is a new one, and making its place is the right answer.
public enum Dock {

    public static let slots = 1...4

    public struct Link: Equatable, Sendable {
        public let secret: String
        public let slot: Int
    }

    /// What goes on a slot's tag. `scripts/dock-tags.sh` writes the same shape.
    public static func url(secret: String, slot: Int, domain: String = Links.domain) -> URL {
        URL(string: "https://\(domain)/d/\(secret)/\(slot)")!
    }

    /// The box and slot from a tag's link, or `reclaim://d/<secret>/<slot>` —
    /// the app's own scheme, which the simulator opens without a signed build.
    public static func link(from url: URL, domain: String = Links.domain) -> Link? {
        let parts = url.pathComponents.filter { $0 != "/" }
        let secret: String, slot: String
        switch url.scheme?.lowercased() {
        case "https" where url.host?.lowercased() == domain && parts.count == 3 && parts[0] == "d":
            (secret, slot) = (parts[1], parts[2])
        case "reclaim" where url.host == "d" && parts.count == 2:
            (secret, slot) = (parts[0], parts[1])
        default:
            return nil
        }
        guard !secret.isEmpty, let n = Int(slot), slots.contains(n) else { return nil }
        return Link(secret: secret, slot: n)
    }

    /// The light controller numbers its segments from zero; the box, from one.
    public static func segment(forSlot slot: Int) -> Int { slot - 1 }
}
