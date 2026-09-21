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

    /// `Copy("place.stage.since", "month", "March")` → "Since March."
    public static func callAsFunction(_ key: String, _ substitutions: String...) -> String {
        var out = Copy[key]
        var i = 0
        while i + 1 < substitutions.count {
            out = out.replacingOccurrences(of: "{\(substitutions[i])}", with: substitutions[i + 1])
            i += 2
        }
        return out
    }

    public static func apply(overrides new: [String: String]) { overrides = new }
}

/// `t("home.headline")` — short enough to use everywhere without friction.
public func t(_ key: String) -> String { Copy[key] }
public func t(_ key: String, _ substitutions: String...) -> String {
    var out = Copy[key]
    var i = 0
    while i + 1 < substitutions.count {
        out = out.replacingOccurrences(of: "{\(substitutions[i])}", with: substitutions[i + 1])
        i += 2
    }
    return out
}
