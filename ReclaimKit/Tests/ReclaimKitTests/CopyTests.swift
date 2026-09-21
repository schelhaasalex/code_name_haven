import XCTest
@testable import ReclaimKit

/// The voice is the product's primary asset, so `strings.json` is treated as
/// source rather than as content: these tests read the file in the repository,
/// not just the copy that happens to be in the bundle.
final class CopyTests: XCTestCase {

    // MARK: - The file

    /// Every substitution token that some call site actually replaces. A token
    /// in the copy that isn't here is a `{name}` that ships to a person
    /// verbatim — the failure is silent in production, where a missing key
    /// renders as an empty string.
    private let knownTokens: Set<String> = [
        "count", "day", "duration", "from", "handle", "month", "name", "names",
        "place", "stage", "time", "to"
    ]

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ReclaimKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ReclaimKit
            .deletingLastPathComponent()   // repo root
    }

    private func json(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private var source: URL { repoRoot.appendingPathComponent("copy/strings.json") }
    private var bundled: URL {
        repoRoot.appendingPathComponent(
            "ReclaimKit/Sources/ReclaimKit/Resources/strings.json")
    }

    /// The app reads the bundled copy; a person editing the voice edits
    /// `copy/strings.json`. If the two drift, the edit silently does nothing.
    func testTheBundledCopyMatchesTheSourceOfTruth() throws {
        let a = try json(at: source), b = try json(at: bundled)
        XCTAssertEqual(a.keys.sorted(), b.keys.sorted(),
                       "copy/strings.json and the bundled resource have different keys")
        for key in a.keys {
            XCTAssertEqual(a[key] as? String, b[key] as? String, "\(key) differs")
        }
    }

    func testEveryTokenIsOneSomethingSubstitutes() throws {
        let strings = try json(at: source)
        let pattern = try NSRegularExpression(pattern: "\\{([a-z_]+)\\}")

        for (key, value) in strings {
            guard let line = value as? String else { continue }
            let range = NSRange(line.startIndex..., in: line)
            for match in pattern.matches(in: line, range: range) {
                let token = String(line[Range(match.range(at: 1), in: line)!])
                XCTAssertTrue(knownTokens.contains(token),
                              "\(key) uses {\(token)}, which nothing substitutes")
            }
        }
    }

    func testKeysAreScreenDotElement() throws {
        for key in try json(at: source).keys where key != "_" {
            XCTAssertTrue(key.contains("."), "\(key) is not keyed screen.element")
            XCTAssertEqual(key, key.lowercased(), "\(key) is not lowercase")
        }
    }

    // MARK: - Lookup

    func testKnownKeyReadsFromTheBundle() {
        XCTAssertEqual(Copy["welcome.headline"],
                       "Set your phone down. We'll take it from here.")
    }

    func testMissingKeyIsVisibleInDevelopment() {
        #if DEBUG
        XCTAssertEqual(Copy["nope.not.a.key"], "⟨nope.not.a.key⟩")
        #else
        XCTAssertEqual(Copy["nope.not.a.key"], "")
        #endif
    }

    func testListReadsAnArrayAndNeverThrows() {
        XCTAssertFalse(Copy.list("naming.suggestions").isEmpty)
        XCTAssertTrue(Copy.list("welcome.headline").isEmpty)   // a string, not a list
        XCTAssertTrue(Copy.list("nope.not.a.key").isEmpty)
    }

    // MARK: - Substitution

    func testSubstitutionReplacesEveryOccurrence() {
        // rhythmended.body names {count} twice.
        let out = t("rhythmended.body", "count", "eleven")
        XCTAssertFalse(out.contains("{count}"))
        XCTAssertEqual(out.components(separatedBy: "eleven").count - 1, 2)
    }

    func testSubstitutionTakesPairsAndIgnoresAStray() {
        XCTAssertEqual(t("places.row.body", "stage", "A regular", "count", "9"),
                       "A regular · 9 evenings")
        XCTAssertEqual(t("places.row.body", "stage", "A regular", "count"),
                       "A regular · {count} evenings")
    }

    func testAnUnknownTokenLeavesTheLineAlone() {
        XCTAssertEqual(t("home.suggestion.title", "nonsense", "x"),
                       Copy["home.suggestion.title"])
    }

    // MARK: - Overrides

    /// The Supabase copy table wins over the bundle, so the voice can change
    /// without an App Store release.
    func testOverridesWinAndOnlyForKeysTheyName() {
        defer { Copy.apply(overrides: [:]) }
        let bundledBody = Copy["welcome.body"]
        Copy.apply(overrides: ["welcome.headline": "Put it down."])
        XCTAssertEqual(Copy["welcome.headline"], "Put it down.")
        XCTAssertEqual(Copy["welcome.body"], bundledBody)
    }
}
