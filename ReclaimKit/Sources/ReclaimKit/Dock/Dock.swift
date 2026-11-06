import Foundation

/// The box: four slots in a drawer, each with a tag under where the top of a
/// phone lands, and a code printed on the outside.
///
/// A slot's tag carries `https://<domain>/p/<secret>/<slot>`; the box's code,
/// `https://<domain>/p/<secret>`. The secret is the box's, the same on all of
/// them, and it is written before anyone owns the box — so the first phone to
/// read any of them makes its place (`dock_place`, migration 0013), and every
/// phone after that becomes one of its people (0017).
///
/// A tag is read with the phone in the slot, so it is the phone going in. The
/// code is read with the phone in a hand: it pairs, and starts nothing.
///
/// Under `/p/` because a phone only opens the app for paths it has already
/// been told about, and it is told rarely: iOS caches the site's
/// apple-app-site-association for days, apart from the app. The first slot
/// links were `/d/`, and a phone installed before `/d/` existed sent them to
/// Safari until its cache happened to refresh. `/p/` has been claimed since
/// the first cards, and the code has their shape. `/d/` tags still read.
public enum Dock {

    public static let slots = 1...4

    public struct Link: Equatable, Sendable {
        public let secret: String
        /// Nil for the box's code: the phone is in a hand, not a slot.
        public let slot: Int?

        public init(secret: String, slot: Int?) { self.secret = secret; self.slot = slot }
    }

    /// What goes on a slot's tag, or with no slot, in the box's code.
    /// `scripts/dock-tags.sh` writes the same shapes.
    public static func url(secret: String, slot: Int? = nil, domain: String = Links.domain) -> URL {
        URL(string: "https://\(domain)/p/\(secret)" + (slot.map { "/\($0)" } ?? ""))!
    }

    /// The box, and the slot if it was a tag, from a link — or from
    /// `reclaim://d/<secret>[/<slot>]`, the app's own scheme, which the
    /// simulator opens without a signed build.
    public static func link(from url: URL, domain: String = Links.domain) -> Link? {
        let parts = url.pathComponents.filter { $0 != "/" }
        let rest: ArraySlice<String>
        switch url.scheme?.lowercased() {
        case "https" where url.host?.lowercased() == domain && (2...3).contains(parts.count)
                           && ["p", "d"].contains(parts[0]):
            rest = parts.dropFirst()
        case "reclaim" where url.host == "d" && (1...2).contains(parts.count):
            rest = parts[...]
        default:
            return nil
        }
        guard let secret = rest.first, !secret.isEmpty else { return nil }
        guard rest.count == 2 else { return Link(secret: secret, slot: nil) }
        guard let n = Int(rest[rest.startIndex + 1]), slots.contains(n) else { return nil }
        return Link(secret: secret, slot: n)
    }

    /// The light controller numbers its segments from zero; the box, from one.
    public static func segment(forSlot slot: Int) -> Int { slot - 1 }
}
