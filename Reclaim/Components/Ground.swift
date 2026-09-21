import SwiftUI
import ReclaimKit

/// The warm paper ground, or the near-black one, plus gutters and safe area.
///
/// The switch between them IS the ceremony — it's what you see across a table
/// out of the corner of an eye — so it lives in one place and no screen sets
/// its own background.
struct Ground: ViewModifier {
    var night: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .background((night ? Palette.night : Palette.bone).ignoresSafeArea())
            .preferredColorScheme(night ? .dark : .light)
    }
}

extension View {
    func ground(night: Bool = false) -> some View { modifier(Ground(night: night)) }
}
