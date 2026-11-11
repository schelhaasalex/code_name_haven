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
            XCTAssertFalse(reason.nudges(place: "The Harbor").isEmpty, reason.stem)
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

    /// The nudge names the box, and never counts days, gaps or anyone else.
    func testNudgesInviteAndNeverCount() {
        for reason in Reason.offered + [.own("Piano practice")] {
            for line in reason.nudges(place: "The Harbor") {
                XCTAssertTrue(line.contains("The Harbor"), line)
                XCTAssertFalse(line.contains("{"), line)
                for word in ["haven't", "missed", "streak", "days", "waiting", "!"] {
                    XCTAssertFalse(line.lowercased().contains(word), "\(line) says \(word)")
                }
            }
        }
    }

    /// Their own words, as typed: a name is how someone writes it.
    func testOwnWordsAreKeptAsTyped() {
        let r = Reason.own("Ellie's recital")
        XCTAssertEqual(r.label, "Ellie's recital")
        XCTAssertEqual(r.purpose, "for Ellie's recital")
        XCTAssertTrue(r.headline.contains("Ellie's recital"))
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
