import XCTest
@testable import ReclaimKit

final class ReasonTests: XCTestCase {

    /// Every reason offered has every line it needs, so none of them reaches
    /// a person as ⟨key⟩. The keys are built from the stem, which
    /// `scripts/shape.sh` can't see.
    func testEveryReasonHasItsWords() {
        for reason in Reason.offered + [.own("The garden")] {
            for part in ["for", "headline"] {
                XCTAssertFalse(Copy["reason.\(reason.stem).\(part)"].isEmpty, "reason.\(reason.stem).\(part)")
            }
            XCTAssertFalse(reason.label.isEmpty)
        }
        for reason in Reason.offered {
            XCTAssertFalse(Copy["reason.\(reason.stem).label"].isEmpty, "reason.\(reason.stem).label")
        }
    }

    /// "for", never "with": the app knows what was said, not who was there.
    func testItSaysWhatWasSaidNotWhatHappened() {
        for reason in Reason.offered {
            XCTAssertFalse(reason.purpose.contains("with"), reason.purpose)
        }
    }

    /// Their own words, as typed: a name is how someone writes it.
    func testOwnWordsAreKeptAsTyped() {
        let r = Reason.own("Ellie's recital")
        XCTAssertEqual(r.label, "Ellie's recital")
        XCTAssertEqual(r.purpose, "for Ellie's recital")
        XCTAssertEqual(r.headline, "Some time for Ellie's recital.")
    }

    /// "The garden", as the placeholder suggests, reads "for the garden" in a
    /// sentence — and "the garden" typed small opens a line with a capital.
    func testOwnWordsTakeTheirCapitalFromWhereTheyStand() {
        let typedBig = Reason.own("The garden")
        XCTAssertEqual(typedBig.headline, "Some time for the garden.")
        XCTAssertEqual(typedBig.purpose, "for the garden")
        XCTAssertEqual(typedBig.label, "The garden")

        let typedSmall = Reason.own("the garden")
        XCTAssertEqual(typedSmall.label, "The garden")
        XCTAssertEqual(t("end.reason", "why", typedSmall.label), "The garden, you said.")
        XCTAssertEqual(typedSmall.purpose, "for the garden")

        // A name keeps its capital; a word spelled with one inside keeps its shape.
        XCTAssertEqual(Reason.own("Sunday lunch").purpose, "for Sunday lunch")
        XCTAssertEqual(Reason.own("iPad-free dinners").label, "iPad-free dinners")
    }

    func testItKeepsAcrossALaunch() {
        for reason in Reason.offered + [.own("The garden")] {
            XCTAssertEqual(Reason(stored: reason.stored), reason)
        }
        XCTAssertNil(Reason(stored: "own:   "))
        XCTAssertNil(Reason(stored: "something we never offered"))
    }

    /// "In your own words" with nothing typed is no choice yet.
    func testOwnWordsNeedWords() {
        XCTAssertNil(Reason.chosen(.own(""), words: "  "))
        XCTAssertEqual(Reason.chosen(.own(""), words: " The garden "), .own("The garden"))
        XCTAssertEqual(Reason.chosen(.book, words: "ignored"), .book)
        XCTAssertNil(Reason.chosen(nil, words: ""))
    }
}
