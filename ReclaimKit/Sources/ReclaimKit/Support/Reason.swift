import Foundation

/// What someone would like the time for: one of the app's own few, or their
/// own words. Asked once, under a receipt; changed on its own page.
///
/// It is what they SAID, never what happened. The app knows the phone was in
/// the box, not who was at the table or whether a book was open (rule 6), so
/// every line built from it says "for the kids", never "with the kids".
///
/// It belongs to this phone. Nothing sends it anywhere, nobody at the box
/// sees it (rule 1), and it never reaches a lock screen — not the Live
/// Activity's, which the room can see, nor the daily nudge's, which anyone
/// near the phone can (`scripts/shape.sh`).
public enum Reason: Hashable, Sendable {
    case kids, eachOther, book, outside, sleep, making, quiet
    /// In their own words, as typed. The app doesn't correct how someone
    /// writes a name; it only moves a capital (`sentence`, `midSentence`).
    case own(String)

    /// The ones offered, in the order they're offered.
    public static let offered: [Reason] = [.kids, .eachOther, .book, .outside, .sleep, .making, .quiet]

    /// The stem of its copy keys: `reason.<stem>.label`, `.for`, `.headline`.
    public var stem: String {
        switch self {
        case .kids:      "kids"
        case .eachOther: "each"
        case .book:      "book"
        case .outside:   "outside"
        case .sleep:     "sleep"
        case .making:    "make"
        case .quiet:     "quiet"
        case .own:       "own"
        }
    }

    /// "The kids", or their words. It starts a line wherever it's shown — a
    /// title, an eyebrow, "The garden, you said." — so it opens with a capital.
    public var label: String { words.map(Self.sentence) ?? t("reason.\(stem).label") }

    /// "for the kids" — the receipt's "An hour back, for the kids."
    public var purpose: String { phrase("for") }

    /// Home's headline while today waits: "Some time for the kids."
    public var headline: String { phrase("headline") }

    private var words: String? {
        if case .own(let w) = self { w } else { nil }
    }

    private func phrase(_ part: String) -> String {
        t("reason.\(stem).\(part)", "words", words.map(Self.midSentence) ?? "")
    }

    // MARK: Their words in a sentence

    /// Words that open a phrase and aren't a name: "The garden" reads "for the
    /// garden" mid-sentence. Anything else — "Ellie's recital", "Sunday
    /// lunch" — may be a name, and keeps its capital.
    static let lowered: Set<String> = ["the", "a", "an", "my", "our", "your", "some", "more", "less"]

    /// Mid-sentence: "The garden" → "the garden"; "Ellie's recital" as typed.
    static func midSentence(_ words: String) -> String {
        guard let first = words.split(separator: " ").first,
              lowered.contains(first.lowercased()) else { return words }
        return words.prefix(1).lowercased() + words.dropFirst()
    }

    /// Opening a line: "the garden" → "The garden". Not "iPad-free" → "IPad".
    static func sentence(_ words: String) -> String {
        let chars = Array(words)
        guard let first = chars.first, first.isLowercase,
              !(chars.count > 1 && chars[1].isUppercase) else { return words }
        return first.uppercased() + words.dropFirst()
    }

    // MARK: Kept on this phone

    /// How it's written down: its stem, or "own:" and the words.
    public var stored: String { words.map { "own:" + $0 } ?? stem }

    public init?(stored: String) {
        if stored.hasPrefix("own:") {
            let words = String(stored.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { return nil }
            self = .own(words)
            return
        }
        guard let found = Self.offered.first(where: { $0.stem == stored }) else { return nil }
        self = found
    }

    /// What a picker holds, as a reason: their words once there are some,
    /// and nothing for "in your own words" with the field still empty.
    public static func chosen(_ picked: Reason?, words: String) -> Reason? {
        guard case .own = picked else { return picked }
        let typed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? nil : .own(typed)
    }

    public var isOwn: Bool { words != nil }
}
