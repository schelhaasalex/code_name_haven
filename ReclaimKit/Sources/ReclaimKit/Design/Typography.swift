import SwiftUI

/// Fraunces for display, Work Sans for everything else.
///
/// Both are OFL and free to bundle. Until the .ttf files are added to
/// Reclaim/Resources/Fonts, these fall back to the system serif and sans, which
/// keeps the app building and running from the first commit — check `isCustom`
/// if you want to know which you're looking at.
public enum Type {
    public static let displayName = "Fraunces"
    public static let bodyName    = "WorkSans-Regular"

    public static var isCustom: Bool {
        UIFont(name: displayName, size: 12) != nil
    }

    /// Fraunces. Used large and sparingly.
    public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        UIFont(name: displayName, size: size) != nil
            ? .custom(displayName, size: size)
            : .system(size: size, weight: weight, design: .serif)
    }

    public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        UIFont(name: bodyName, size: size) != nil
            ? .custom(bodyName, size: size)
            : .system(size: size, weight: weight)
    }

    // the scale, so screens don't invent sizes
    public static var hero: Font      { display(44) }
    public static var title: Font     { display(34) }
    public static var subhead: Font   { display(24) }
    public static var timer: Font     { display(92, weight: .light) }
    public static var lede: Font      { body(16) }
    public static var note: Font      { body(13) }
    public static var label: Font     { body(12, weight: .semibold) }
}

public extension View {
    /// The small letterspaced caps used for eyebrows throughout.
    func eyebrow(_ color: Color) -> some View {
        self.font(Type.label)
            .textCase(.uppercase)
            .tracking(1.9)
            .foregroundStyle(color)
    }
}
