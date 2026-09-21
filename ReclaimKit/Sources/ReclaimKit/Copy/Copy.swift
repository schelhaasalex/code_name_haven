import Foundation

/// Every user-facing string, keyed `screen.element`.
///
/// The voice is the product's primary asset, so it must be changeable without
/// an App Store release: `strings.json` ships in the bundle as the fallback and
/// a table fetched from Supabase overrides it at launch.
///
/// NEVER hardcode a user-facing string in a view.
public enum Copy {

    nonisolated(unsafe) private static var bundled: [String: Any] = load()
    nonisolated(unsafe) private static var overrides: [String: String] = [:]

    private static func load() -> [String: Any] {
        guard let url = Bundle.module.url(forResource: "strings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    public static subscript(_ key: String) -> String {
        if let o = overrides[key] { return o }
        if let s = bundled[key] as? String { return s }
        #if DEBUG
        return "⟨\(key)⟩"   // visible in development, so a missing key is obvious
        #else
        return ""
        #endif
    }

    public static func list(_ key: String) -> [String] {
        bundled[key] as? [String] ?? []
    }

    public static func apply(overrides new: [String: String]) { overrides = new }
}

/// `t("home.headline")`, or `t("place.stage.since", "month", "March")` →
/// "Since March." Short enough to use everywhere without friction, and the one
/// substitution path — a token nothing replaces reaches a person verbatim.
///
/// A template that OPENS with `{count}` starts a sentence with the app's own
/// lowercase word — "three evenings this week" — so its first letter is
/// capitalised. Only `{count}`: a name or a place is what a person typed, and
/// the app doesn't correct how someone writes their own kitchen.
public func t(_ key: String, _ substitutions: String...) -> String {
    let template = Copy[key]
    var out = template
    var i = 0
    while i + 1 < substitutions.count {
        out = out.replacingOccurrences(of: "{\(substitutions[i])}", with: substitutions[i + 1])
        i += 2
    }
    if template.hasPrefix("{count}"), let first = out.first {
        out = first.uppercased() + out.dropFirst()
    }
    return out
}
