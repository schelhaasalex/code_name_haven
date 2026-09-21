import SwiftUI
import ReclaimKit

/// The ring-and-dot mark. A table seen from above.
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

struct Eyebrow: View {
    let text: String
    var mark: Color = Palette.clay
    var tint: Color = Palette.muted
    var body: some View {
        HStack(spacing: 10) {
            Brand(color: mark)
            Text(text).eyebrow(tint)
        }
    }
}

/// One phone at the table. Fills when its owner joins; turns over when they
/// set it down. There is no empty slot for someone who hasn't — the app has no
/// roster, and naming who's missing is the thing this product replaces.
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
                .foregroundStyle(isMe ? (night ? Palette.ember : Palette.clay)
                                      : (night ? Palette.dust : Palette.ink2))
                .lineLimit(1)
        }
        .frame(width: 58)
    }
}

struct PrimaryButton: View {
    let title: String
    var night: Bool = false
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Type.body(17, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 60)
                .foregroundStyle(night ? Palette.night : Palette.bone)
                .background(tint ?? (night ? Palette.cream : Palette.ink),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct QuietButton: View {
    let title: String
    var night: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Type.body(15, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(night ? Palette.dust : Palette.muted)
                .overlay {
                    if night { Capsule().stroke(Palette.edge, lineWidth: 1) }
                }
        }
        .buttonStyle(.plain)
    }
}

/// The week of dots on Home's footer — and the route to your rhythm, which is
/// one of only three destinations in the app.
struct DotWeek: View {
    /// true = docked, false = missed, nil = still to come
    let days: [Bool?]
    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Group {
                    switch day {
                    case .some(true):  Circle().fill(Palette.ink)
                    case .some(false): Circle().fill(Palette.line)
                    case .none:        Circle().stroke(Palette.hairline, lineWidth: 1)
                    }
                }
                .frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The warm paper ground, or the near-black one. The switch between them is
/// the ceremony — it's what you see across a table out of the corner of an eye.
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
