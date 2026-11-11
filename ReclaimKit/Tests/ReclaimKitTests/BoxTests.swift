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

    /// A dock across the room, or next door, is not the one whose card was read.
    func testPairingTakesNothingFarAway() {
        XCTAssertNil(Box.closest([UUID(): -82]))
        XCTAssertNil(Box.closest([:]))
    }

    /// The bedroom's card, read in the doorway: the kitchen's box is louder,
    /// and already this phone's.
    func testPairingSkipsThePhonesOtherBoxes() {
        let kitchen = UUID(), bedroom = UUID()
        XCTAssertEqual(Box.closest([kitchen: -45, bedroom: -62], except: [kitchen]), bedroom)
        XCTAssertNil(Box.closest([kitchen: -45], except: [kitchen]), "nothing new heard")
    }

    /// Two boxes side by side on a packing line: the card names its own, and
    /// the louder one beside it is not it.
    func testACardThatNamesItsBoxPairsWithThatBox() {
        let mine = UUID(), beside = UUID()
        let names = [mine: "Portside-0A1B2C3D", beside: "Portside-99887766"]
        XCTAssertEqual(Box.closest([mine: -70, beside: -40], named: "0a1b2c3d", names: names), mine)
    }

    /// The named box is certain, so a weak signal is still the right box —
    /// and a card whose box isn't heard pairs with nothing, never the closest.
    func testANamedBoxIsNeverSwappedForAnother() {
        let mine = UUID(), beside = UUID()
        let names = [mine: "Portside-0A1B2C3D", beside: "Portside-99887766"]
        XCTAssertEqual(Box.closest([mine: -88], named: "0A1B2C3D", names: names), mine)
        XCTAssertNil(Box.closest([beside: -35], named: "0A1B2C3D", names: names))
        XCTAssertNil(Box.closest([UUID(): -35], named: "0A1B2C3D"), "a dock with no name isn't the named one")
    }

    func testABoxsIdentityIsItsRadioName() {
        XCTAssertEqual(Box.name(of: "0a1b2c3d"), "Portside-0A1B2C3D")
        XCTAssertTrue(Box.isID("0A1B2C3D"))
        XCTAssertTrue(Box.isID("A1B2"), "the first boards named themselves with four")
        for bad in ["", "A1B", "0A1B2C3DE", "XYZW", "0A1B-2C3"] { XCTAssertFalse(Box.isID(bad), bad) }
    }

    // MARK: - Was it this phone?

    func testThePhoneThatJustStartedChargingBesideTheBoxIsIn() {
        XCTAssertTrue(Box.isThisPhone(charging: true, wasCharging: false, rssi: -42))
    }

    /// Already on the bedside charger when someone else's phone went in.
    func testAPhoneAlreadyChargingIsNotIn() {
        XCTAssertFalse(Box.isThisPhone(charging: true, wasCharging: true, rssi: -42))
    }

    /// Seen charging last night, unplugged while the app slept, and in the
    /// box this morning: right beside it, so it's this one.
    func testAChargingStretchTheAppSleptThroughIsDecidedByCloseness() {
        XCTAssertTrue(Box.isThisPhone(charging: true, wasCharging: true, unbroken: false, rssi: -42))
        XCTAssertFalse(Box.isThisPhone(charging: true, wasCharging: true, unbroken: false, rssi: -78))
        // Asleep through it and nothing read: not enough to start anything.
        XCTAssertFalse(Box.isThisPhone(charging: true, wasCharging: true, unbroken: false, rssi: nil))
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
