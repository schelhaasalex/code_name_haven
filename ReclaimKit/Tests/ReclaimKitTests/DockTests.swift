import XCTest
@testable import ReclaimKit

final class DockTests: XCTestCase {

    private let domain = "links.example"

    /// The factory's cards say which box they belong to.
    func testACardNamesItsBox() {
        let code = Dock.url(secret: "box", box: "0a1b2c3d", domain: domain)
        XCTAssertEqual(code.absoluteString, "https://links.example/p/box?b=0A1B2C3D")
        XCTAssertEqual(Dock.link(from: code, domain: domain), Dock.Link(secret: "box", box: "0A1B2C3D"))
    }

    /// A `b` that isn't a box's name still opens the box; it just pairs with
    /// the closest, as the first cards do.
    func testANonsenseBoxIsIgnoredNotFatal() {
        let url = URL(string: "https://links.example/p/box?b=not-a-box")!
        XCTAssertEqual(Dock.link(from: url, domain: domain), Dock.Link(secret: "box", box: nil))
    }

    /// The box's code pairs, and starts nothing. A trailing slash is still it.
    func testTheCodeIsTheBox() {
        XCTAssertEqual(Dock.link(from: URL(string: "https://links.example/p/box/")!, domain: domain),
                       Dock.Link(secret: "box"))
        let code = Dock.url(secret: "box", domain: domain)
        XCTAssertEqual(code.absoluteString, "https://links.example/p/box")
        XCTAssertEqual(Dock.link(from: code, domain: domain), Dock.Link(secret: "box"))
    }

    /// The slots' tags are gone (rule 4: only the box's radio starts an
    /// evening). A link of their shape — under `/p/` or the first `/d/` — is
    /// no box's, and does nothing; so is the app's own scheme, which the
    /// simulator once used to stand in for a tag.
    func testASlotsOldLinkIsNoBoxs() {
        for text in ["https://links.example/p/box/1",
                     "https://links.example/p/box/4?b=0A1B2C3D",
                     "https://links.example/d/box/2",
                     "https://links.example/d/box",
                     "reclaim://d/box/3",
                     "reclaim://d/box"] {
            XCTAssertNil(Dock.link(from: URL(string: text)!, domain: domain), text)
        }
    }

    /// An invite was `/i/`; nothing but `/p/` is a box — and a box on
    /// someone else's domain is not a box.
    func testNothingElseIsADock() {
        for text in ["https://links.example/i/token",
                     "https://links.example/p",
                     "https://elsewhere.example/p/box",
                     "http://links.example/p/box",
                     "https://links.example/p/box/1/extra"] {
            XCTAssertNil(Dock.link(from: URL(string: text)!, domain: domain), text)
        }
    }

    // MARK: - Leaving

    func testAPhoneJustSetDownHasNotLeft() {
        let now = Date()
        // The charger takes a moment after the phone lands; that isn't leaving.
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
