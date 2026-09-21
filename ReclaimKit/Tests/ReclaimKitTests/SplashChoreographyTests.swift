import XCTest
@testable import ReclaimKit

/// A splash is the one screen nobody asked for, so the things worth asserting
/// about it are all about restraint: it ends, it ends soon, nothing is still
/// arriving while it leaves, and there is a still moment in the middle.
final class SplashChoreographyTests: XCTestCase {

    /// Both of the things screen 0 can be: moving, and not.
    private let every: [SplashChoreography] = [.settle, .still]

    // MARK: - It ends, and soon

    func testTheSplashDoesNotOutstayTheCeiling() {
        XCTAssertLessThanOrEqual(
            SplashChoreography.settle.total, SplashChoreography.ceiling,
            "past the ceiling a brand moment is a wait"
        )
    }

    func testEveryBeatIsRealAndForwards() {
        for c in every {
            for beat in [c.figure, c.core, c.word, c.exit] {
                XCTAssertGreaterThanOrEqual(beat.delay, 0)
                XCTAssertGreaterThan(beat.duration, 0, "a beat with no duration is a beat nobody sees")
            }
            XCTAssertGreaterThan(c.hold, 0, "the still moment is the difference from a spinner")
        }
    }

    // MARK: - Nothing arrives on its way out

    func testTheWordmarkLandsBeforeTheDissolveBegins() {
        for c in every {
            XCTAssertLessThanOrEqual(
                c.word.end, c.exit.delay,
                "the wordmark is still fading in while the layer fades out"
            )
        }
    }

    func testTheFigureAndCoreBothFinishBeforeTheWordmarkLands() {
        for c in every {
            XCTAssertLessThanOrEqual(c.figure.end, c.word.end)
            XCTAssertLessThanOrEqual(c.core.end, c.word.end)
        }
    }

    func testTheDotOverlapsTheRingRatherThanQueueingAfterIt() {
        // It is one gesture, not two. If the dot waits politely for the ring to
        // finish drawing, it reads as a checklist.
        let c = SplashChoreography.settle
        XCTAssertLessThan(c.core.delay, c.figure.end, "the beats queue — they should overlap")
    }

    /// The hold is what separates the last thing arriving from the dissolve.
    func testHoldMatchesTheGapItDescribes() {
        for c in every {
            XCTAssertEqual(c.exit.delay - c.word.end, c.hold, accuracy: 0.0001,
                           "hold says one thing and the beats say another")
        }
    }

    // MARK: - Reduce Motion

    func testReduceMotionGetsTheStillFrameAndNotAFasterOne() {
        XCTAssertEqual(SplashChoreography.launch(reduceMotion: true), .still)
        XCTAssertEqual(SplashChoreography.launch(reduceMotion: false), .settle)
    }

    func testTheStillVersionIsShortAndStillHolds() {
        XCTAssertLessThanOrEqual(SplashChoreography.still.total, 0.7)
        XCTAssertGreaterThanOrEqual(
            SplashChoreography.still.hold, 0.2,
            "without a hold the motionless splash is a flicker, which is worse than no splash"
        )
        // Nothing may travel: the figure and core are instant, not fast.
        XCTAssertLessThanOrEqual(SplashChoreography.still.figure.duration, 0.02)
        XCTAssertLessThanOrEqual(SplashChoreography.still.core.duration, 0.02)
    }

    // MARK: - Review mode

    func testScalingStretchesDelayAndDurationTogether() {
        let beat = SplashChoreography.Beat(delay: 0.5, duration: 0.25)
        let half = beat.scaled(by: 2)
        XCTAssertEqual(half.delay, 1.0, accuracy: 0.0001)
        XCTAssertEqual(half.duration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(half.end, 1.5, accuracy: 0.0001)
    }
}
