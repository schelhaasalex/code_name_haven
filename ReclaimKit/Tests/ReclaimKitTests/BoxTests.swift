import XCTest
@testable import ReclaimKit

final class BoxTests: XCTestCase {

    // MARK: - The slot state

    func testEachByteIsASlot() {
        XCTAssertEqual(Box.Slots(state: Data([0, 0, 0, 0]))?.full, [])
        XCTAssertEqual(Box.Slots(state: Data([1, 0, 0, 0]))?.full, [1])
        // Charging and full are both a phone in the slot.
        XCTAssertEqual(Box.Slots(state: Data([0, 2, 0, 1]))?.full, [2, 4])
    }

    /// The one-slot test dock sends one byte.
    func testADockWithFewerSlotsSendsFewerBytes() {
        XCTAssertEqual(Box.Slots(state: Data([1]))?.full, [1])
    }

    func testOnlyOneToFourBytesIsASlotState() {
        XCTAssertNil(Box.Slots(state: Data()))
        XCTAssertNil(Box.Slots(state: Data([0, 0, 0, 0, 1])))
        XCTAssertNil(Box.Slots(state: nil))
    }

    func testFilledAndEmptiedAreTheDifference() {
        let before = Box.Slots(full: [1, 2])
        let now = Box.Slots(full: [2, 3])
        XCTAssertEqual(now.filled(since: before), [3])
        XCTAssertEqual(now.emptied(since: before), [1])
    }

    func testAFifthSlotIsNothing() {
        XCTAssertEqual(Box.Slots(full: [1, 5]).full, [1])
        XCTAssertEqual(Box.Slots(bits: 0b1_0000).full, [])
    }

    // MARK: - Events

    func testTheDocksEventIsRead() {
        let json = #"{"v":1,"slot":3,"event":"docked","t":1767225600,"mA":640,"V":10.1}"#
        XCTAssertEqual(Box.Event(Data(json.utf8)), Box.Event(slot: 3, kind: "docked"))
    }

    func testAnotherVersionIsNotReadAsThisOne() {
        XCTAssertNil(Box.Event(Data(#"{"v":2,"slot":1,"event":"docked"}"#.utf8)))
        XCTAssertNil(Box.Event(Data("not json".utf8)))
    }

    func testEventsMoveTheSlots() {
        let one = Box.Slots(full: [1])
        XCTAssertEqual(one.after(Box.Event(slot: 2, kind: "docked")).full, [1, 2])
        XCTAssertEqual(one.after(Box.Event(slot: 1, kind: "undocked")).full, [])
    }

    /// A phone that stopped drawing much — full, or paused at 80% — is still in.
    func testFullAndPongChangeNothing() {
        let one = Box.Slots(full: [1])
        XCTAssertEqual(one.after(Box.Event(slot: 1, kind: "full")), one)
        XCTAssertEqual(one.after(Box.Event(slot: nil, kind: "pong")), one)
        XCTAssertEqual(one.after(Box.Event(slot: 9, kind: "docked")), one)
    }

    func testTheTimeIsSentAsTheDockExpects() {
        let sent = String(decoding: Box.timeCommand(at: Date(timeIntervalSince1970: 1_767_225_600)), as: UTF8.self)
        XCTAssertEqual(sent, #"{"cmd":"time","epoch":1767225600}"#)
    }

    // MARK: - Pairing

    func testPairingTakesTheClosestDock() {
        let here = UUID(), there = UUID()
        XCTAssertEqual(Box.closest([here: -41, there: -66]), here)
    }

    /// A dock across the room, or next door, is not the one whose tag was read.
    func testPairingTakesNothingFarAway() {
        XCTAssertNil(Box.closest([UUID(): -82]))
        XCTAssertNil(Box.closest([:]))
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
