import Foundation

/// What can go wrong reading a box's link that the person should hear about
/// in its own words, rather than as "check you're online".
public enum DockError: Error, Equatable, Sendable {
    /// A code another phone showed, an hour or more ago (migration 0025). It
    /// pairs no one, and — the point — never makes a new box.
    case codeRanOut

    /// The SQLSTATE `dock_place` raises it with.
    public static let ranOutCode = "RC410"
}
