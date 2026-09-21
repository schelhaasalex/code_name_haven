import SwiftUI
import ReclaimKit

/// One phone at the table. Fills when its owner joins, turns over when they set
/// it down.
///
/// There is deliberately NO empty-slot variant. The app has no roster of who's
/// present, so an empty slot would be a name it doesn't have — and drawing one
/// is how a warm screen becomes a checklist of who hasn't complied yet.
struct PhoneSlab: View {
    let name: String
    var isMe: Bool = false
    var isDown: Bool = false
    var night: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9)
                .fill(night ? Palette.ember : Palette.ink)
                .frame(width: 38, height: 54)
                .rotationEffect(.degrees(isDown ? 180 : 0))
                .scaleEffect(y: isDown ? 0.84 : 1)
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isDown)
            Text(isMe ? "You" : name)
                .font(Type.body(13))
                .foregroundStyle(nameTint)
                .lineLimit(1)
        }
        .frame(width: 58)
    }

    private var nameTint: Color {
        if isMe { return night ? Palette.ember : Palette.clay }
        return night ? Palette.dust : Palette.ink2
    }
}

#Preview {
    HStack(spacing: 16) {
        PhoneSlab(name: "Maya", isDown: true)
        PhoneSlab(name: "Dad")
        PhoneSlab(name: "Alex", isMe: true, isDown: true)
    }
    .padding()
}
