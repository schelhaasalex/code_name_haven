import SwiftUI
import ReclaimKit

/// The bordered off-white block. Four screens draw this; before it existed they
/// each drew it slightly differently.
struct PaperCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).stroke(Palette.line, lineWidth: 1) }
    }
}

/// Its counterpart on the session screens.
struct NightCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x1E1A14), in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).stroke(Color(hex: 0x332B22), lineWidth: 1) }
    }
}

/// A dashed outline — for something that exists but hasn't been given a name.
/// Never framed as a deficiency: "Somewhere" is a valid, permanent state.
struct DashedCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
    }
}

/// Label on the left, a display-face figure on the right.
struct StatRow: View {
    let title: String
    var subtitle: String?
    let value: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(Type.note).foregroundStyle(Palette.muted)
                }
            }
            Spacer()
            Text(value).font(Type.display(28)).foregroundStyle(Palette.ink)
        }
    }
}

/// Eyebrow caps over a stack. Used through settings, places and the place view.
struct LabelledSection<Content: View>: View {
    let label: String
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).eyebrow(Palette.muted)
            VStack(alignment: .leading, spacing: spacing) { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 16) {
        PaperCard { StatRow(title: "The Kitchen Table", subtitle: "Counted to the cap", value: "2h") }
        DashedCard { Text("Somewhere").font(Type.display(21)).foregroundStyle(Palette.ink2) }
        LabelledSection(label: "How it works") {
            Text("An evening counts once you've been away fifteen minutes.")
                .font(Type.body(14)).foregroundStyle(Palette.ink2)
        }
    }
    .padding()
    .background(Palette.bone)
}

extension View {
    /// For a control that can't be wrapped in `PaperCard` without losing its
    /// binding — a Toggle, mainly.
    func paperCard(padding: CGFloat = 18, radius: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).stroke(Palette.line, lineWidth: 1) }
    }
}
