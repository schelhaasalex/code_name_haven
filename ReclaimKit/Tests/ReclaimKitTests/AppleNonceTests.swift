import XCTest
@testable import ReclaimKit

final class AppleNonceTests: XCTestCase {

    /// The published SHA-256 test vector for "abc". If this is wrong, Supabase
    /// rejects every sign-in, and nothing says why.
    func testTheHashIsSHA256InLowercaseHex() {
        XCTAssertEqual(AppleNonce.hashed("abc"),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testANonceIsTheLengthAskedFor() {
        XCTAssertEqual(AppleNonce.make().count, 32)
        XCTAssertEqual(AppleNonce.make(length: 48).count, 48)
    }

    func testNoTwoNoncesAreTheSame() {
        let many = Set((0..<200).map { _ in AppleNonce.make() })
        XCTAssertEqual(many.count, 200)
    }
}
