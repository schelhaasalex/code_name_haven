import SwiftUI
import CoreText

/// Fraunces for display, Work Sans for everything else — the card's faces, so
/// the app and the card in the box are one voice.
///
/// Both are OFL, bundled in this package (`Resources/Fonts`, with their
/// licences), and both are variable: one file holds every weight, so a weight
/// is a value on the font's `wght` axis rather than a separate file. Fraunces
/// also draws itself for the size it's set at (`opsz`), as it does on the card,
/// where Chrome does the same. The station prints the card from these same
/// files (`scripts/dock-tags.sh`).
///
/// Registered with the process the first time a face is asked for, so the app
/// and anything else that imports this package find them without an Info.plist
/// entry. Should that ever fail, the system serif and sans stand in.
public enum Type {
    public static let displayName = "Fraunces-Regular"
    public static let bodyName    = "WorkSans-Regular"

    /// Fraunces. Used large and sparingly.
    public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        face(displayName, size: size, weight: weight, opticalSize: true)
            .map(Font.init) ?? .system(size: size, weight: weight, design: .serif)
    }

    public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        face(bodyName, size: size, weight: weight, opticalSize: false)
            .map(Font.init) ?? .system(size: size, weight: weight)
    }

    // the scale, so screens don't invent sizes
    public static var hero: Font      { display(44) }
    public static var title: Font     { display(34) }
    public static var subhead: Font   { display(24) }
    public static var lede: Font      { body(16) }
    public static var note: Font      { body(13) }
    public static var label: Font     { body(12, weight: .semibold) }

    // MARK: The faces

    /// True once both files are registered. Once per process.
    static let registered: Bool = {
        for file in ["Fraunces", "WorkSans"] {
            let url = Bundle.module.url(forResource: file, withExtension: "ttf")
                ?? Bundle.module.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts")
            // Fails harmlessly when already registered, as in a preview.
            if let url { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
        return UIFont(name: displayName, size: 12) != nil && UIFont(name: bodyName, size: 12) != nil
    }()

    /// `name` at `size`, its weight set on the `wght` axis and, for Fraunces,
    /// its optical size to match. Nil if the fonts aren't there.
    static func face(_ name: String, size: CGFloat, weight: Font.Weight, opticalSize: Bool) -> UIFont? {
        guard registered else { return nil }
        var axes: [UInt32: CGFloat] = [axis("wght"): wght(weight)]
        if opticalSize { axes[axis("opsz")] = min(max(size, 9), 144) }
        let descriptor = UIFontDescriptor(name: name, size: size)
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): axes])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Font.Weight on the 100–900 scale the `wght` axis uses.
    static func wght(_ weight: Font.Weight) -> CGFloat {
        let scale: [(Font.Weight, CGFloat)] = [
            (.ultraLight, 200), (.thin, 100), (.light, 300), (.regular, 400), (.medium, 500),
            (.semibold, 600), (.bold, 700), (.heavy, 800), (.black, 900),
        ]
        return scale.first { $0.0 == weight }?.1 ?? 400
    }

    /// A four-letter axis tag as the number Core Text keys variations by.
    static func axis(_ tag: String) -> UInt32 {
        tag.unicodeScalars.reduce(0) { $0 << 8 | $1.value }
    }
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
