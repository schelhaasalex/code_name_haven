import Foundation

/// What the app should do when it comes back to the foreground, given what it
/// thinks is running and what the database says is.
///
/// `load()` runs on every foreground. It used to re-adopt a running evening
/// each time — restarting the Live Activity, rejoining the channel — and never
/// noticed one that had ended elsewhere, so the session screen could count up
/// for an evening that was over. Pure so each case can be tested without a
/// phone or a network.
public enum Reconciliation: Equatable, Sendable {
    /// The read failed. Change nothing: a network blip must never end an
    /// evening on screen — the worst failure this product can have (rule 4).
    case keep
    /// Still the same evening. Catch up on who joined while the app was away.
    case refresh
    /// An evening this phone didn't start here: Siri, a tag, Control Centre.
    case adopt(Session)
    /// Ended elsewhere — the Live Activity, Siri, or closed at the cap.
    case end
    /// Nothing running, nothing to do but listen at your places.
    case idle

    public static func between(running: Session?, database: Result<Session?, any Error>) -> Self {
        guard case .success(let found) = database else { return .keep }
        switch (running, found) {
        case let (mine?, found?) where mine.id == found.id: return .refresh
        case (_, let found?):                               return .adopt(found)
        case (_?, nil):                                     return .end
        case (nil, nil):                                    return .idle
        }
    }
}
