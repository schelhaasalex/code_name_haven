import SwiftUI
import ReclaimKit

/// The mark: a ring with a dot at its centre. A table seen from above.
struct Brand: View {
    var color: Color = Palette.clay
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: size * 0.068).frame(width: size * 0.84)
            Circle().fill(color).frame(width: size * 0.3)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        Brand()
        Brand(color: Palette.ember, size: 44)
    }
    .padding()
}
