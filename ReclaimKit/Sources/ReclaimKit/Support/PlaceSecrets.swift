import Foundation
import Security

/// Where a place's join secret lives after it is minted.
///
/// The database stores only `sha256(secret)` — deliberately, so that reading
/// every row of `places` still doesn't let anyone join an evening. The plaintext
/// exists for exactly as long as it takes to put it on a card, and then only
/// here: the Keychain of the device that created the place, synchronised across
/// that person's own devices by iCloud.
///
/// The consequence is honest and has to be shown rather than hidden: on a device
/// that never held the secret, the card cannot be redrawn. Screen 15 says so.
/// The alternative — storing the plaintext server-side — would undo the reason
/// the column is a hash, and rotating the secret would brick a card already
/// printed and stuck to someone's fridge (schema review, finding 8).
public enum PlaceSecrets {

    private static let service = "app.reclaim.place-secret"

    public static func save(_ secret: String, for place: UUID) {
        guard let data = secret.data(using: .utf8) else { return }
        SecItemDelete(query(for: place) as CFDictionary)

        var item = query(for: place)
        item[kSecValueData as String] = data
        // Available after first unlock rather than only while unlocked: a tag
        // write or a card render can be kicked off from a Shortcut.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    public static func secret(for place: UUID) -> String? {
        var item = query(for: place)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func forget(_ place: UUID) {
        SecItemDelete(query(for: place) as CFDictionary)
    }

    private static func query(for place: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: place.uuidString,
            // So a card made on the phone can be reprinted from the iPad.
            kSecAttrSynchronizable as String: true
        ]
    }
}
