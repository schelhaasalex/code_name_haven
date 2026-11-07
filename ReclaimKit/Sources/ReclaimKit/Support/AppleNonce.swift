import Foundation
import CryptoKit
import Security

/// The nonce that ties one Sign in with Apple request to the token it returns.
///
/// Apple is given the SHA-256 of a fresh random string and bakes it into the
/// identity token; Supabase is given the string itself and checks the two
/// match. A token captured on its way somewhere else can't then be replayed
/// into a session here — the nonce it carries was never ours to hand over.
public enum AppleNonce {

    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    /// A fresh random nonce. From the system's secure generator, not
    /// `Int.random`: the whole point is that nobody can guess it.
    public static func make(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "No secure randomness for a sign-in nonce")
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }

    /// What Apple is given: lowercase hex SHA-256.
    public static func hashed(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
