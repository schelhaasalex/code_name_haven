import Foundation

/// Screen 0's timing.
///
/// The numbers live here rather than in the view for the reason every other
/// piece of reasoning in this package does: a delay is a decision, and a
/// decision inside a `View` cannot be tested, compared or changed in one place.
/// `prototype/splash.html` runs the same four beats at the same durations, so
/// what you review in a browser is what the phone does.
///
/// Two other options were built against this one — a phone turning over, and a
/// light coming up over the mark — and not chosen. They live on in the
/// prototype, which is where a comparison belongs, rather than in a `switch`
/// the app carries forever for a decision already made.
///
/// The four beats:
///
/// | Beat     | What moves          |
/// |----------|---------------------|
/// | `figure` | the ring draws      |
/// | `core`   | the dot settles     |
/// | `word`   | the wordmark        |
/// | `exit`   | the layer dissolves |
///
/// `hold` is the still moment between the wordmark landing and the dissolve
/// starting. It is the whole difference between a brand moment and a loading
/// spinner, and it is the first thing anyone deletes, so it is a named field.
public struct SplashChoreography: Equatable, Sendable {

    /// A delay and a duration, both in seconds.
    public struct Beat: Equatable, Sendable {
        public let delay: Double
        public let duration: Double

        public init(delay: Double, duration: Double) {
            self.delay = delay
            self.duration = duration
        }

        public var end: Double { delay + duration }

        /// Used by the prototype's half-speed review mode and by nothing that
        /// ships.
        public func scaled(by factor: Double) -> Beat {
            Beat(delay: delay * factor, duration: duration * factor)
        }
    }

    public let figure: Beat
    public let core: Beat
    public let word: Beat
    public let hold: Double
    public let exit: Beat

    /// How long the whole thing takes, dissolve included.
    public var total: Double { exit.end }

    /// A splash may not hold the app for longer than this. Not a style
    /// preference: it plays over a launch that may already be done, and past
    /// about two and a half seconds a brand moment has become a thing standing
    /// between someone and the reason they opened the app.
    public static let ceiling: Double = 2.5

    public init(figure: Beat, core: Beat, word: Beat, hold: Double, exit: Beat) {
        self.figure = figure
        self.core = core
        self.word = word
        self.hold = hold
        self.exit = exit
    }

    /// What screen 0 runs on, or the motionless version of it.
    ///
    /// Reduce Motion is not a degraded path here. Rule 4 says a sensor may only
    /// offer; the same courtesy applies to a preference someone has already
    /// stated — if they have asked for less movement, the answer is a splash
    /// that doesn't move, not this one played faster.
    public static func launch(reduceMotion: Bool) -> SplashChoreography {
        reduceMotion ? .still : .settle
    }
}

public extension SplashChoreography {

    /// The ring draws itself, the dot settles into the middle of it. A table
    /// being laid.
    static let settle = SplashChoreography(
        figure: Beat(delay: 0.06, duration: 0.62),
        core:   Beat(delay: 0.50, duration: 0.38),
        word:   Beat(delay: 0.78, duration: 0.46),
        hold:   0.30,
        exit:   Beat(delay: 1.54, duration: 0.40)
    )

    /// Under Reduce Motion. Nothing travels and nothing rotates — the composed
    /// mark fades up, rests long enough to be a deliberate frame rather than a
    /// flicker, and fades out. Still a splash; just one that doesn't move.
    static let still = SplashChoreography(
        figure: Beat(delay: 0, duration: 0.01),
        core:   Beat(delay: 0, duration: 0.01),
        word:   Beat(delay: 0, duration: 0.24),
        hold:   0.22,
        exit:   Beat(delay: 0.46, duration: 0.22)
    )
}
