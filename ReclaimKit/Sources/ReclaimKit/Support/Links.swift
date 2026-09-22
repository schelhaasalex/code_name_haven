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
}
