import Foundation
import Security

/// A place carries two identifiers doing different jobs.
///
/// `handle` is a generated word pair — "amber-otter" — printed on the card.
/// Sayable down a phone, easy to tell two cards apart, stable forever.
/// DISPLAY ONLY.
///
/// `secret` is a long random value that lives in the NFC tag and the QR and is
/// the actual join credential. If the sayable identifier were also sufficient
/// to join, a small dictionary would be brute-forceable and "being in the room"
/// would quietly stop being the access control.
public enum Handle {

    private static let adjectives = [
        "amber", "quiet", "slow", "plain", "calm", "warm", "low", "still",
        "soft", "bright", "old", "kind", "near", "open", "clear", "long"
    ]
    private static let creatures = [
        "otter", "heron", "marten", "badger", "wren", "hare", "finch", "moth",
        "swift", "pike", "crane", "vole", "linnet", "ibis", "shrike", "teal"
    ]

    /// Matches the `places_handle_format` check in migration 0001.
    public static func generate() -> String {
        "\(adjectives.randomElement()!)-\(creatures.randomElement()!)"
    }

    public static func pretty(_ handle: String) -> String {
        handle.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }

    /// 32 bytes, URL-safe. The database stores only its SHA-256.
    public static func newSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// What goes on the tag and in the QR. An https URL, because iOS only
    /// offers to open http(s) from a background NFC read — a custom scheme
    /// would need the app already open, which defeats the point.
    public static func cardURL(secret: String, domain: String = "reclaim.app") -> URL {
        URL(string: "https://\(domain)/p/\(secret)")!
    }

    public static func secret(fromCardURL url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "p" else { return nil }
        return parts[1]
    }
}
