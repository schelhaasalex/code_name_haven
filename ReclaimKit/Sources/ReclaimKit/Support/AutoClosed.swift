import Foundation

/// Screen 13: an evening the server closed at its cap — a phone left in the
/// box overnight, or one whose leaving was never heard — said once, over Home,
/// the next time the person looks. It is the only screen that interrupts.
///
/// Pure so it can be tested without a phone or a network.
public enum AutoClosed {

    /// How far back is still worth explaining: the night before, not last week.
    public static let window: TimeInterval = 60 * 60 * 36

    /// Where the server closes an evening nobody ended (`app.auto_close_minutes`,
    /// 0004). The lock screen goes quiet at it, in case the push that ends it
    /// never arrives.
    public static let capMinutes = 180
    public static let cap: TimeInterval = TimeInterval(capMinutes * 60)

    /// The most recent one, whatever order the rows arrive in.
    public static func latest(in recent: [Session]) -> Session? {
        recent.filter(\.autoClosed).max { $0.startedAt < $1.startedAt }
    }
}
