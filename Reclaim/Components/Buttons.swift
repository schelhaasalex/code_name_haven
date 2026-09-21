import SwiftUI
import ReclaimKit

/// The heavy one. There is at most one per screen — if a screen seems to need
/// two, one of them is a QuietButton.
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
                .background(tint ?? (night ? Palette.cream : Palette.ink), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The light one. Declining is always as easy as accepting — that's most of
/// what keeps this product from nagging.
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
                .overlay { if night { Capsule().stroke(Palette.edge, lineWidth: 1) } }
        }
        .buttonStyle(.plain)
    }
}

/// A plain text action, left-aligned. Used where a control should read as a
/// sentence rather than a button.
struct TextAction: View {
    let title: String
    var tint: Color = Palette.muted
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 15)) }
                Text(title).font(Type.body(15, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Set it down") {}
        QuietButton(title: "Not right now") {}
        TextAction(title: "Sign out") {}
    }
    .padding()
}
