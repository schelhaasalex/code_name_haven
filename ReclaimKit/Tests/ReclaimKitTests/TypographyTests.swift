import XCTest
import CoreText
@testable import ReclaimKit

/// The faces are bundled and found. Without this, a missing file is the
/// system serif on every screen, and nothing says so — it was, for months.
final class TypographyTests: XCTestCase {

    func testBothFacesAreBundledAndRegister() {
        XCTAssertTrue(Type.registered)
        XCTAssertEqual(Type.face(Type.displayName, size: 34, weight: .regular, opticalSize: true)?.familyName,
                       "Fraunces")
        XCTAssertEqual(Type.face(Type.bodyName, size: 16, weight: .regular, opticalSize: false)?.familyName,
                       "Work Sans")
    }

    /// A weight is a place on the `wght` axis: semibold is heavier than
    /// regular, from the same file.
    func testWeightIsSetOnTheAxis() throws {
        let regular = try XCTUnwrap(Type.face(Type.bodyName, size: 12, weight: .regular, opticalSize: false))
        let semibold = try XCTUnwrap(Type.face(Type.bodyName, size: 12, weight: .semibold, opticalSize: false))
        // Core Text leaves out an axis at its default, which for wght is 400.
        XCTAssertEqual(variation(regular, "wght") ?? 400, 400)
        XCTAssertEqual(variation(semibold, "wght"), 600)
    }

    /// Fraunces at 52 is drawn for 52; at 400, for its largest, 144.
    func testFrauncesDrawsForItsSize() throws {
        let big = try XCTUnwrap(Type.face(Type.displayName, size: 52, weight: .light, opticalSize: true))
        XCTAssertEqual(variation(big, "opsz"), 52)
        let huge = try XCTUnwrap(Type.face(Type.displayName, size: 400, weight: .light, opticalSize: true))
        XCTAssertEqual(variation(huge, "opsz"), 144)
    }

    private func variation(_ font: UIFont, _ tag: String) -> CGFloat? {
        let values = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber]
        return values?[NSNumber(value: Type.axis(tag))].map { CGFloat($0.doubleValue) }
    }
}
