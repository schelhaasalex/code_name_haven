import Foundation

/// A place carries two identifiers doing different jobs.
///
/// `handle` is a generated word pair — "amber-otter" — that the database
/// requires of every place. DISPLAY ONLY.
///
/// The box's `secret` is a long random value on its tags and in its code, and
/// is the actual join credential. If the sayable identifier were also
/// sufficient to join, a small dictionary would be brute-forceable and "being
/// at the box" would quietly stop being the access control.
public enum Handle {

    private static let adjectives = [
        "amber", "quiet", "slow", "plain", "calm", "warm", "low", "still",
        "soft", "bright", "old", "kind", "near", "open", "clear", "long"
    ]
    private static let creatures = [
        "otter", "heron", "marten", "badger", "wren", "hare", "finch", "moth",
        "swift", "pike", "crane", "vole", "linnet", "ibis", "shrike", "teal"
    ]

    /// Matches the `places_handle_format` check in migration 0001.
    public static func generate() -> String {
        "\(adjectives.randomElement()!)-\(creatures.randomElement()!)"
    }

    public static func pretty(_ handle: String) -> String {
        handle.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }
}
