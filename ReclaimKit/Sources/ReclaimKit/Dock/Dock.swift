import Foundation

/// The box: four slots in a drawer, and a code printed on its card.
///
/// The code is `https://<domain>/p/<secret>`. The secret is the box's, written
/// before anyone owns it — so the first phone to read it makes its place
/// (`dock_place`, migration 0013), and every phone after that becomes one of
/// its people (0017). A phone already in the box can show the same link with
/// a fresh, hour-long secret (`box_code`, 0025), for a phone without the card.
/// Either is read with the phone in a hand: it pairs, and starts nothing.
/// Only the box's radio starts an evening (CLAUDE.md rule 4).
///
/// Cards made at the factory also say which box they belong to, as `?b=<id>`
/// — the box's radio name (`Box.name(of:)`) — so a phone pairs with that box
/// and not merely the closest one. The first cards have no `b`, and pair with
/// the closest, as they always did.
///
/// The slots had NFC tags once, with links of their own (`/p/<secret>/<slot>`,
/// and before that `/d/`), that started an evening. No box has them now, and
/// a link of that shape is no box's: it does nothing.
public enum Dock {

    public static let slots = 1...4

    public struct Link: Equatable, Sendable {
        public let secret: String
        /// The box's radio, as the factory printed it; nil on the first cards.
        public let box: String?

        public init(secret: String, box: String? = nil) {
            self.secret = secret; self.box = box
        }
    }

    /// The box's code, as its card carries it. `scripts/dock-tags.sh` writes
    /// the same shape.
    public static func url(secret: String, box: String? = nil, domain: String = Links.domain) -> URL {
        URL(string: "https://\(domain)/p/\(secret)" + (box.map { "?b=\($0.uppercased())" } ?? ""))!
    }

    /// The box from its code, or nil for anything that isn't one.
    public static func link(from url: URL, domain: String = Links.domain) -> Link? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard url.scheme?.lowercased() == "https", url.host?.lowercased() == domain,
              parts.count == 2, parts[0] == "p", !parts[1].isEmpty
        else { return nil }
        // A `b` that isn't a box's name is ignored, not fatal: the card still
        // opens its box, and pairs with the closest dock as the first ones did.
        let box = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "b" }?.value
            .flatMap { Box.isID($0) ? $0.uppercased() : nil }
        return Link(secret: parts[1], box: box)
    }
}
