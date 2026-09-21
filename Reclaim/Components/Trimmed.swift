import Foundation

extension String {
    /// A name is what's left after the spaces. " The Deck " and "The Deck" are
    /// the same place, and a field holding only spaces is an empty field.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
