import XCTest
@testable import ReclaimKit

/// A box's code shown by a phone already in it (migration 0025): the card's
/// link, drawn on a screen, read by the other phone as the card would be.
final class BoxCodeTests: XCTestCase {

    private let domain = "links.example"
    /// The shape the server makes: 32 random bytes, URL-safe, 43 characters.
    private let secret = "Zq3x_9QwP2vLm8RtY4nBc6ZsD1fGh7KaE0jHuW5oX-s"

    /// A phone's code is a card: the scanner can't tell them apart, and
    /// doesn't need to. It pairs and starts nothing.
    func testAPhonesCodeReadsAsTheCard() {
        let url = Dock.url(secret: secret, box: "0ACEC38D", domain: domain)
        XCTAssertEqual(Dock.link(from: url, domain: domain),
                       Dock.Link(secret: secret, slot: nil, box: "0ACEC38D"))
    }

    /// Without the box's name — a phone that hasn't read the card on this
    /// launch — it is the first cards' shape, and pairs with the closest box.
    func testACodeWithoutTheBoxStillReads() {
        let url = Dock.url(secret: secret, domain: domain)
        XCTAssertEqual(Dock.link(from: url, domain: domain), Dock.Link(secret: secret, slot: nil, box: nil))
    }

    /// Square, with the four-module margin the standard asks for: a phone
    /// reads it off a screen only if the quiet zone is there.
    func testTheQRHasItsQuietMargin() throws {
        let text = Dock.url(secret: secret, box: "0ACEC38D", domain: domain).absoluteString
        let image = try XCTUnwrap(QRCode.image(for: text))
        XCTAssertEqual(image.width, image.height)

        let bare = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator",
                                          parameters: ["inputMessage": Data(text.utf8),
                                                       "inputCorrectionLevel": "M"])?.outputImage)
        // Core Image's own margin is one module; three more on each side.
        XCTAssertEqual(image.width, Int(bare.extent.width) + 6)
    }

    func testTheSampleHouseholdHasACode() async throws {
        let repo = PreviewRepository()
        let code = try await repo.boxCode(place: PreviewRepository.kitchenTable)
        XCTAssertNotNil(Dock.link(from: Dock.url(secret: code, domain: domain), domain: domain))
    }
}
