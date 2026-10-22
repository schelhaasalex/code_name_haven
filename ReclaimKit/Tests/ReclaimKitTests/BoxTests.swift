import XCTest
@testable import ReclaimKit

final class BoxTests: XCTestCase {

    // MARK: - Who the box is

    /// The firmware is flashed with this, from `scripts/dock-tags.sh`, which
    /// computes it with `shasum`. If the two disagree, no phone ever pairs.
    func testTheIdIsTheStartOfTheSecretsHash() {
        // printf %s 'box-secret' | shasum -a 256 | cut -c1-16
        let hex = Box.id(secret: "box-secret").map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "f30ecd80ad24cf13")
    }

    func testTheIdNeverCarriesTheSecret() {
        let secret = "a-long-secret-from-the-factory"
        XCTAssertEqual(Box.id(secret: secret).count, 8)
        XCTAssertNotEqual(Box.id(secret: secret), Data(secret.utf8.prefix(8)))
    }

    // MARK: - The slots byte

    func testEachBitIsASlot() {
        XCTAssertEqual(Box.Slots(bits: 0b0000).full, [])
        XCTAssertEqual(Box.Slots(bits: 0b0001).full, [1])
        XCTAssertEqual(Box.Slots(bits: 0b1010).full, [2, 4])
        // A fifth bit is nothing: the box has four slots.
        XCTAssertEqual(Box.Slots(bits: 0b1_0000).full, [])
    }

    func testOnlyOneByteIsASlotsByte() {
        XCTAssertEqual(Box.Slots(Data([0b0100])), Box.Slots(bits: 0b0100))
        XCTAssertNil(Box.Slots(Data()))
        XCTAssertNil(Box.Slots(Data([1, 2])))
        XCTAssertNil(Box.Slots(nil))
    }

    func testFilledAndEmptiedAreTheDifference() {
        let before = Box.Slots(bits: 0b0011)
        let now = Box.Slots(bits: 0b0110)
        XCTAssertEqual(now.filled(since: before), [3])
        XCTAssertEqual(now.emptied(since: before), [1])
    }

    // MARK: - Was it this phone?

    func testThePhoneThatJustStartedChargingBesideTheBoxIsIn() {
        XCTAssertTrue(Box.isThisPhone(charging: true, wasCharging: false, rssi: -42))
    }

    /// Already on the bedside charger when someone else's phone went in.
    func testAPhoneAlreadyChargingIsNotIn() {
        XCTAssertFalse(Box.isThisPhone(charging: true, wasCharging: true, rssi: -42))
    }

    /// In a pocket, in the same room.
    func testAPhoneNotChargingIsNotIn() {
        XCTAssertFalse(Box.isThisPhone(charging: false, wasCharging: false, rssi: -42))
    }

    /// Put on a charger in the next room at the same moment.
    func testAPhoneChargingFarFromTheBoxIsNotIn() {
        XCTAssertFalse(Box.isThisPhone(charging: true, wasCharging: false, rssi: -78))
    }

    func testAnUnreadSignalDoesNotCountAgainstIt() {
        XCTAssertTrue(Box.isThisPhone(charging: true, wasCharging: false, rssi: nil))
    }

    func testChargingIsNewsForHalfAMinute() {
        let at = Date()
        XCTAssertTrue(Box.justStarted(chargingSince: at.addingTimeInterval(-5), at: at))
        // The pad often starts after the sensor: charging a moment later is news too.
        XCTAssertTrue(Box.justStarted(chargingSince: at.addingTimeInterval(3), at: at))
        XCTAssertFalse(Box.justStarted(chargingSince: at.addingTimeInterval(-600), at: at))
        XCTAssertFalse(Box.justStarted(chargingSince: nil, at: at))
    }

    // MARK: - Leaving

    func testAPhoneStillChargingDidNotLeave() {
        XCTAssertFalse(Box.hasLeft(docked: true, charging: true))
        XCTAssertTrue(Box.hasLeft(docked: true, charging: false))
        XCTAssertFalse(Box.hasLeft(docked: false, charging: false))
    }
}
