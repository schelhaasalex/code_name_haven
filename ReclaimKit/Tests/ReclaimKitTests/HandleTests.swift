import XCTest
@testable import ReclaimKit

final class HandleTests: XCTestCase {

    /// `places_handle_format` in migration 0001. A generated handle that fails
    /// it takes down `create_place` at runtime, with a constraint violation
    /// nobody would connect back to the generator.
    private let databaseFormat = "^[a-z]+-[a-z]+$"

    func testEveryGeneratedHandleSatisfiesTheDatabaseCheck() {
        for _ in 0..<500 {
            let handle = Handle.generate()
            XCTAssertNotNil(handle.range(of: databaseFormat, options: .regularExpression),
                            "\(handle) would be rejected by places_handle_format")
        }
    }

    func testTheVocabularyItselfSatisfiesIt() {
        // Catches a word added with an apostrophe, a space or a capital, which
        // random generation might not surface for a hundred runs.
        let seen = Set((0..<2_000).map { _ in Handle.generate() })
        for handle in seen {
            XCTAssertNotNil(handle.range(of: databaseFormat, options: .regularExpression))
        }
        // Two sixteen-word lists. If generation collapsed onto one pair this
        // would be the test that noticed.
        XCTAssertGreaterThan(seen.count, 100)
    }

    func testPrettyIsForReadingAloud() {
        XCTAssertEqual(Handle.pretty("amber-otter"), "Amber Otter")
        XCTAssertEqual(Handle.pretty("wren"), "Wren")
    }
}
