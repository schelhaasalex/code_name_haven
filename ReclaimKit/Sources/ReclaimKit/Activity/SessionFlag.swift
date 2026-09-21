import Foundation

/// Whether an evening is running, in the one place both processes can see it.
///
/// The Control Centre toggle lives in a widget extension and cannot ask the
/// app — or the database — what state it should draw. It needs an answer
/// instantly and offline, so the app writes this flag as the session starts and
/// ends, and the control reads it.
///
/// It is a mirror, never the truth: the database owns what a session is. If the
/// two ever disagree, the toggle is briefly wrong and one tap fixes it, which
/// is the correct way round for something this cheap.
public enum SessionFlag {
    public static let appGroup = "group.com.reclaim.app"
    private static let key = "reclaim.session.live"

    private static var store: UserDefaults? { UserDefaults(suiteName: appGroup) }

    public static var isLive: Bool {
        get { store?.bool(forKey: key) ?? false }
        set { store?.set(newValue, forKey: key) }
    }
}
