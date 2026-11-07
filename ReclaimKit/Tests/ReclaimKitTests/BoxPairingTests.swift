import XCTest
@testable import ReclaimKit

/// The boxes a phone belongs to, as this phone keeps them.
final class BoxPairingTests: XCTestCase {

    private var saved: [BoxPairing] = []
    override func setUp() { saved = BoxPairing.all; BoxPairing.all = [] }
    override func tearDown() { BoxPairing.all = saved }

    func testASecondBoxIsAddedNotSwapped() {
        let kitchen = UUID(), bedroom = UUID(), kitchenRadio = UUID()
        BoxPairing.met(kitchen, peripheral: kitchenRadio)
        BoxPairing.met(bedroom)
        XCTAssertEqual(BoxPairing.all.map(\.place), [kitchen, bedroom], "in the order they were met")
        XCTAssertEqual(BoxPairing.place(of: kitchenRadio), kitchen)
    }

    /// Read again with no radio heard: the one it knew stays.
    func testMeetingAgainKeepsTheRadio() {
        let kitchen = UUID(), radio = UUID()
        BoxPairing.met(kitchen, peripheral: radio)
        BoxPairing.met(kitchen)
        XCTAssertEqual(BoxPairing.all, [BoxPairing(place: kitchen, peripheral: radio)])
    }

    /// A radio is one box's. Heard for the bedroom, it's no longer the kitchen's.
    func testOneRadioIsOneBox() {
        let kitchen = UUID(), bedroom = UUID(), radio = UUID()
        BoxPairing.met(kitchen, peripheral: radio)
        BoxPairing.met(bedroom, peripheral: radio)
        XCTAssertNil(BoxPairing.all.first { $0.place == kitchen }?.peripheral)
        XCTAssertEqual(BoxPairing.place(of: radio), bedroom)
    }

    func testForgettingOneKeepsTheOther() {
        let kitchen = UUID(), bedroom = UUID()
        BoxPairing.met(kitchen)
        BoxPairing.met(bedroom)
        BoxPairing.forget(kitchen)
        XCTAssertEqual(BoxPairing.all.map(\.place), [bedroom])
    }

    /// A phone paired before there could be several still has its box.
    func testTheOneBoxFromBeforeIsKept() throws {
        let kitchen = UUID(), radio = UUID()
        UserDefaults.standard.removeObject(forKey: "dock.boxes")
        UserDefaults.standard.set(try JSONEncoder().encode(BoxPairing(place: kitchen, peripheral: radio)),
                                  forKey: "dock.box")
        XCTAssertEqual(BoxPairing.all, [BoxPairing(place: kitchen, peripheral: radio)])
    }
}
