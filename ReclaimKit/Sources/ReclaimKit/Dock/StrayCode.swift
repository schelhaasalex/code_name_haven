import Foundation

/// A QR code in the scanner that isn't a box's: when to say so.
///
/// Silence was the old answer, and someone holding up the wrong code — a
/// sticker, a menu, the back of the card — saw nothing happen and decided the
/// box was broken. Now the line under the frame says it's a different code,
/// once one has been held up for a moment (a code swept past on the way to the
/// card isn't worth a word), and goes back once it has been out of view a
/// little while. Pure, so the timing can be tested without a camera.
public struct StrayCode: Equatable, Sendable {
    /// How long one has to be in view before it's mentioned.
    public static let settle: TimeInterval = 1
    /// How long the line stays once it's gone.
    public static let linger: TimeInterval = 2
    /// The camera reports a code in view many times a second; a pause longer
    /// than this means it left and came back, and starts the count again.
    static let gap: TimeInterval = 0.5
    /// Sightings closer together than this change nothing, so a code held
    /// still doesn't redraw the screen at the camera's rate.
    static let step: TimeInterval = 0.2

    private var since: Date?
    private var last: Date?

    public init() {}

    /// A code that isn't the box's, seen at `now`.
    public mutating func seen(at now: Date) {
        if let last, now.timeIntervalSince(last) < Self.step { return }
        if let last, since != nil, now.timeIntervalSince(last) <= Self.gap {
            self.last = now
        } else {
            since = now
            last = now
        }
    }

    /// Whether the line should say it's a different code at `now`.
    public func showing(at now: Date) -> Bool {
        guard let since, let last else { return false }
        return last.timeIntervalSince(since) >= Self.settle - Self.step
            && now.timeIntervalSince(last) <= Self.linger
    }
}
