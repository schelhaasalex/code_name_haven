import Foundation

/// Where the app's links point: a place's card (`/p/…`) and, soon, an
/// invitation (`/i/…`). The site at that domain serves the
/// apple-app-site-association that lets those links open the app (`links/`).
public enum Links {

    /// `LINK_DOMAIN` from project.yml, by way of the app's Info.plist — the
    /// one place the domain is written. There is no real domain yet, and the
    /// business name isn't settled, so this has to change in one line.
    ///
    /// Where the setting is missing — the test runner, a stray preview — it is
    /// deliberately not a real domain: a link built without it should look
    /// wrong, not quietly point somewhere that happens to exist.
    public static var domain: String {
        Bundle.main.object(forInfoDictionaryKey: "LINK_DOMAIN") as? String ?? "links.invalid"
    }

    /// An invite, sent in a message. `/i/`, never `/p/`: a card link starts
    /// an evening, and an invite must not.
    public static func inviteURL(token: String, domain: String = Links.domain) -> URL {
        URL(string: "https://\(domain)/i/\(token)")!
    }

    /// The token from an invite link: `https://<domain>/i/<token>`, or
    /// `reclaim://i/<token>` — the app's own scheme, which the simulator can
    /// open without a signed build (`xcrun simctl openurl booted …`).
    public static func inviteToken(from url: URL, domain: String = Links.domain) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.scheme?.lowercased() {
        case "https" where url.host?.lowercased() == domain && parts.count == 2 && parts[0] == "i":
            return parts[1]
        case "reclaim" where url.host == "i" && parts.count == 1:
            return parts[0]
        default:
            return nil
        }
    }
}
