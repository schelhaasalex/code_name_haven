import SwiftUI
import ReclaimKit

/// A box's radio at a glance: filled when it can hear the phone, hollow when
/// it's away or not heard from yet, clay when Bluetooth is off and someone
/// has to do something about it.
struct StatusDot: View {
    enum Style { case on, quiet, off }

    let style: Style
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(fill)
            .overlay {
                if style == .quiet { Circle().strokeBorder(Palette.hairline, lineWidth: 1.5) }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch style {
        case .on:    Palette.ink
        case .quiet: Color.clear
        case .off:   Palette.clay
        }
    }

    static func style(_ radio: BoxLink.Radio?) -> Style {
        switch radio {
        case .connected: .on
        case .off:       .off
        case .away, nil: .quiet
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        StatusDot(style: .on)
        StatusDot(style: .quiet)
        StatusDot(style: .off, size: 9)
    }
    .padding()
    .background(Palette.bone)
}
