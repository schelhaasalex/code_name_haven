import SwiftUI

/// The product's palette. No literal colors in views.
///
/// Reclaim commits to one visual world rather than tracking the system theme:
/// the waiting screens are warm paper, the session screens are near-black. The
/// switch between them IS the ceremony — it's the thing you see across a table
/// out of the corner of your eye — so it can't be at the mercy of a setting.
public enum Palette {
    // paper
    public static let bone   = Color(hex: 0xF7F4EE)
    public static let paper  = Color(hex: 0xFFFDF8)
    public static let linen  = Color(hex: 0xEFE9DC)
    public static let ink    = Color(hex: 0x1F1B16)
    public static let ink2   = Color(hex: 0x4A4239)
    public static let muted  = Color(hex: 0x6B6155)
    public static let line   = Color(hex: 0xE3DDD1)
    public static let hairline = Color(hex: 0xC9C0B0)
    public static let clay   = Color(hex: 0xB4512C)
    public static let clayDeep = Color(hex: 0x8E3F22)

    // night
    public static let night  = Color(hex: 0x17140F)
    public static let nightDeep = Color(hex: 0x0E0C09)
    public static let nightCard = Color(hex: 0x221D16)
    public static let cream  = Color(hex: 0xF3EDE1)
    public static let dust   = Color(hex: 0xA39685)
    public static let dim    = Color(hex: 0x8E8271)
    public static let edge   = Color(hex: 0x453C30)
    public static let ember  = Color(hex: 0xE08A4E)

    // the rest day marker
    public static let restFill   = Color(hex: 0xE9D8B8)
    public static let restStroke = Color(hex: 0xC9A961)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }
}
