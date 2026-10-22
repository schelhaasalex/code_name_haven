import XCTest
@testable import ReclaimKit

final class DockTests: XCTestCase {

    private let domain = "links.example"

    func testASlotsLinkRoundTrips() {
        for slot in Dock.slots {
            let url = Dock.url(secret: "box-SECRET_1", slot: slot, domain: domain)
            XCTAssertEqual(url.absoluteString, "https://links.example/p/box-SECRET_1/\(slot)")
            XCTAssertEqual(Dock.link(from: url, domain: domain), Dock.Link(secret: "box-SECRET_1", slot: slot))
        }
    }

    /// Tags written before slot links moved under `/p/` keep working.
    func testTheFirstSlotLinksStillRead() {
        let url = URL(string: "https://links.example/d/box/2")!
        XCTAssertEqual(Dock.link(from: url, domain: domain), Dock.Link(secret: "box", slot: 2))
    }

    /// A card and a slot share `/p/`. One more part is the whole difference,
    /// and it has to hold both ways.
    func testACardIsNeverASlotAndASlotIsNeverACard() {
        let card = Handle.cardURL(secret: "box", domain: domain)
        XCTAssertNil(Dock.link(from: card, domain: domain))
        XCTAssertNotNil(Handle.secret(fromCardURL: card))

        let slot = Dock.url(secret: "box", slot: 1, domain: domain)
        XCTAssertNotNil(Dock.link(from: slot, domain: domain))
        XCTAssertNil(Handle.secret(fromCardURL: slot))
    }

    /// The simulator can't read a tag, so the app's own scheme stands in.
    func testTheAppsOwnSchemeOpensASlotToo() {
        let url = URL(string: "reclaim://d/box/3")!
        XCTAssertEqual(Dock.link(from: url, domain: domain), Dock.Link(secret: "box", slot: 3))
    }

    /// A box has four slots. A tag saying anything else is not one of ours,
    /// and lighting segment 4 or -1 would light somebody's shelf.
    func testOnlyTheFourSlotsAreSlots() {
        for bad in ["0", "5", "-1", "two", ""] {
            for path in ["p", "d"] {
                XCTAssertNil(Dock.link(from: URL(string: "https://links.example/\(path)/box/\(bad)")!, domain: domain), bad)
            }
        }
    }

    /// A card is `/p/`, an invite `/i/`; neither may be taken for a box —
    /// and a box on someone else's domain is not a box.
    func testNothingElseIsADock() {
        for text in ["https://links.example/p/secret",
                     "https://links.example/i/token",
                     "https://links.example/i/box/1",
                     "https://links.example/d/box",
                     "https://elsewhere.example/p/box/1",
                     "http://links.example/p/box/1",
                     "https://links.example/p/box/1/extra"] {
            XCTAssertNil(Dock.link(from: URL(string: text)!, domain: domain), text)
        }
        XCTAssertNil(Handle.secret(fromCardURL: Dock.url(secret: "box", slot: 1, domain: domain)))
    }

    func testSlotsCountFromOneAndSegmentsFromZero() {
        XCTAssertEqual(Dock.slots.map(Dock.segment(forSlot:)), [0, 1, 2, 3])
    }

    // MARK: - The wire

    func testOnTurnsTheControllerOnWithTheSlot() throws {
        let json = String(decoding: WLED.state(segment: 2, on: true), as: UTF8.self)
        XCTAssertEqual(json, #"{"on":true,"seg":[{"id":2,"on":true}]}"#)
    }

    /// Off is only that slot. The controller stays on for the phones still in.
    func testOffNeverTurnsTheControllerOff() {
        let json = String(decoding: WLED.state(segment: 0, on: false), as: UTF8.self)
        XCTAssertEqual(json, #"{"seg":[{"id":0,"on":false}]}"#)
    }

    func testTheRequestIsAWholeHTTPPost() {
        let body = WLED.state(segment: 1, on: true)
        let text = String(decoding: WLED.request(body: body), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("POST /json/state HTTP/1.1\r\n"))
        XCTAssertTrue(text.contains("Content-Length: \(body.count)\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n\r\n" + String(decoding: body, as: UTF8.self)))
    }

    // MARK: - Leaving

    func testAPhoneJustSetDownHasNotLeft() {
        let now = Date()
        // The charger takes a moment after the tag; that isn't leaving.
        XCTAssertFalse(DockSlot.hasLeft(since: now.addingTimeInterval(-10), charging: false, now: now))
    }

    func testAPhoneLongOutOfTheBoxHasLeft() {
        let now = Date()
        XCTAssertTrue(DockSlot.hasLeft(since: now.addingTimeInterval(-600), charging: false, now: now))
    }

    func testAPhoneStillChargingHasNotLeft() {
        let now = Date()
        XCTAssertFalse(DockSlot.hasLeft(since: now.addingTimeInterval(-600), charging: true, now: now))
        XCTAssertFalse(DockSlot.hasLeft(since: nil, charging: false, now: now))
    }
}
