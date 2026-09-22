import XCTest
@testable import ReclaimKit

final class HandleTests: XCTestCase {

    /// `places_handle_format` in migration 0001. A generated handle that fails
    /// it takes down `create_place` at runtime, with a constraint violation
    /// nobody would connect back to the generator.
    private let databaseFormat = "^[a-z]+-[a-z]+$"

    func testEveryGeneratedHandleSatisfiesTheDatabaseCheck() {
        for _ in 0..<500 {
            let handle = Handle.generate()
            XCTAssertNotNil(handle.range(of: databaseFormat, options: .regularExpression),
                            "\(handle) would be rejected by places_handle_format")
        }
    }

    func testTheVocabularyItselfSatisfiesIt() {
        // Catches a word added with an apostrophe, a space or a capital, which
        // random generation might not surface for a hundred runs.
        let seen = Set((0..<2_000).map { _ in Handle.generate() })
        for handle in seen {
            XCTAssertNotNil(handle.range(of: databaseFormat, options: .regularExpression))
        }
        // Two sixteen-word lists. If generation collapsed onto one pair this
        // would be the test that noticed.
        XCTAssertGreaterThan(seen.count, 100)
    }

    func testPrettyIsForReadingAloud() {
        XCTAssertEqual(Handle.pretty("amber-otter"), "Amber Otter")
        XCTAssertEqual(Handle.pretty("wren"), "Wren")
    }

    /// The card carries an https URL, not a custom scheme: iOS only offers to
    /// open http(s) from a background NFC read.
    func testCardURLIsHTTPSAndRoundTrips() {
        let secret = "abc-123_XYZ"
        let url = Handle.cardURL(secret: secret)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.absoluteString, "https://\(Links.domain)/p/abc-123_XYZ")
        XCTAssertEqual(Handle.secret(fromCardURL: url), secret)
    }

    func testSomethingElseOnTheDoormatIsNotASecret() {
        for junk in ["https://\(Links.domain)/",
                     "https://\(Links.domain)/p",
                     "https://\(Links.domain)/p/abc/def",
                     "https://\(Links.domain)/x/abc"] {
            XCTAssertNil(Handle.secret(fromCardURL: URL(string: junk)!), junk)
        }
    }

    /// The secret is the actual join credential — it goes in a URL path, so
    /// anything needing escaping there is a bug, and it has to be long enough
    /// that being in the room stays the access control.
    func testSecretsAreURLSafeAndDistinct() {
        let secrets = (0..<200).map { _ in Handle.newSecret() }
        XCTAssertEqual(Set(secrets).count, secrets.count)
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        for secret in secrets {
            XCTAssertGreaterThanOrEqual(secret.count, 40)
            XCTAssertTrue(secret.unicodeScalars.allSatisfy { allowed.contains($0) },
                          "\(secret) needs escaping in a URL path")
            XCTAssertEqual(Handle.secret(fromCardURL: Handle.cardURL(secret: secret)), secret)
        }
    }

    /// The camera reads whatever QR is in front of it. Only a card is a card.
    func testAScannedCardIsRecognised() {
        let printed = Handle.cardURL(secret: "a-long-random-secret").absoluteString
        XCTAssertEqual(Handle.cardURL(fromScanned: printed)?.absoluteString, printed)
        XCTAssertNotNil(Handle.cardURL(fromScanned: "  \(printed)\n"), "stray whitespace from the scanner")
    }

    func testAnythingElseScannedIsNotACard() {
        for text in ["https://example.com/p/a-long-random-secret",   // another site, same shape
                     "http://\(Links.domain)/p/a-long-random-secret",     // not https
                     "https://\(Links.domain)/about",                     // ours, but not a card
                     "reclaim://p/a-long-random-secret",              // a scheme, not a link
                     "WIFI:S:home;T:WPA;P:hunter2;;",                 // somebody's wifi card
                     ""] {
            XCTAssertNil(Handle.cardURL(fromScanned: text), text)
        }
    }

    /// An invite link and a card link must never be mistaken for each other:
    /// one joins a place, the other starts an evening there.
    func testAnInviteLinkRoundTripsAndIsNotACard() {
        let url = Links.inviteURL(token: "tok_123-abc")
        XCTAssertEqual(url.absoluteString, "https://\(Links.domain)/i/tok_123-abc")
        XCTAssertEqual(Links.inviteToken(from: url), "tok_123-abc")
        XCTAssertNil(Handle.secret(fromCardURL: url), "an invite is not a card")
        XCTAssertNil(Links.inviteToken(from: Handle.cardURL(secret: "tok_123-abc")), "a card is not an invite")
    }

    func testTheSimulatorSchemeIsAnInviteToo() {
        XCTAssertEqual(Links.inviteToken(from: URL(string: "reclaim://i/tok")!), "tok")
    }

    func testSomeoneElsesInviteShapedLinkIsNotOurs() {
        for text in ["https://example.com/i/tok", "http://\(Links.domain)/i/tok",
                     "https://\(Links.domain)/i", "https://\(Links.domain)/i/a/b", "reclaim://p/tok"] {
            XCTAssertNil(Links.inviteToken(from: URL(string: text)!), text)
        }
    }
}
