import XCTest
@testable import ReclaimKit

/// The radio's one moment of trust: bytes handed over by a device nobody
/// vouched for. Anything can advertise these ids and answer with anything.
final class NearbyTests: XCTestCase {

    private let good = "abcDEF123-_abcDEF123-_xy"   // 24, base64url

    func testAKeyOfTheRightShapeIsRead() {
        XCTAssertEqual(good.count, Nearby.keyLength)
        XCTAssertEqual(Nearby.key(from: Nearby.data(for: good)), good)
    }

    func testNothingIsNotAKey() {
        XCTAssertNil(Nearby.key(from: nil))
        XCTAssertNil(Nearby.key(from: Data()))
    }

    func testTheWrongLengthIsRefused() {
        XCTAssertNil(Nearby.key(from: Nearby.data(for: String(good.dropLast()))))
        XCTAssertNil(Nearby.key(from: Nearby.data(for: good + "x")))
    }

    /// A token goes into a request; a semicolon, a slash or a quote in one has
    /// no business getting that far.
    func testCharactersOutsideTheAlphabetAreRefused() {
        for bad in ["abcDEF123-_abcDEF123-_x/", "abcDEF123-_abcDEF123-_x'", "abcDEF123 _abcDEF123-_xy"] {
            XCTAssertNil(Nearby.key(from: Nearby.data(for: bad)), bad)
        }
    }

    func testBytesThatAreNotTextAreRefused() {
        XCTAssertNil(Nearby.key(from: Data(repeating: 0xFF, count: Nearby.keyLength)))
    }

    /// Multi-byte characters: 24 bytes that are not 24 characters.
    func testTwentyFourBytesOfSomethingElseIsRefused() {
        let emoji = String(repeating: "🙂", count: 6)   // 24 bytes, 6 characters
        XCTAssertEqual(Nearby.data(for: emoji).count, Nearby.keyLength)
        XCTAssertNil(Nearby.key(from: Nearby.data(for: emoji)))
    }

    // MARK: - Asking once

    func testAKeyIsAskedAboutOnce() {
        var offers = NearbyOffers()
        XCTAssertTrue(offers.firstSight(of: good))
        XCTAssertFalse(offers.firstSight(of: good))
        XCTAssertFalse(offers.firstSight(of: good))
    }

    func testADifferentTableIsADifferentQuestion() {
        var offers = NearbyOffers()
        XCTAssertTrue(offers.firstSight(of: good))
        XCTAssertTrue(offers.firstSight(of: "zzzDEF123-_abcDEF123-_xy"))
    }

    func testForgettingStartsTheEveningOver() {
        var offers = NearbyOffers()
        XCTAssertTrue(offers.firstSight(of: good))
        offers.forget()
        XCTAssertTrue(offers.firstSight(of: good))
    }
}
