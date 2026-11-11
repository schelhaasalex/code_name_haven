import SwiftUI
import ReclaimKit

/// The reasons offered, as chips that wrap, and "In your own words", which
/// opens a field for them. Holds the choice in bindings and knows nothing
/// else: the question and the page each decide what keeping it means.
struct ReasonPicker: View {
    @Binding var picked: Reason?
    @Binding var words: String
    var typing: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Flow(spacing: 8) {
                ForEach(Reason.offered, id: \.self) { reason in
                    chip(reason.label, on: picked == reason) { picked = reason }
                }
                chip(t("reason.ask.own"), on: picked?.isOwn == true, dashed: true) {
                    picked = .own(words)
                    typing.wrappedValue = true
                }
            }
            if picked?.isOwn == true {
                TextField(t("reason.ask.own.placeholder"), text: $words)
                    .font(Type.body(16)).foregroundStyle(Palette.ink)
                    .focused(typing)
                    .submitLabel(.done)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.clay, lineWidth: 1.5) }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: picked)
    }

    private func chip(_ title: String, on: Bool, dashed: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Type.body(15, weight: .medium))
                .foregroundStyle(on ? Palette.bone : (dashed ? Palette.muted : Palette.ink2))
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(on ? Palette.ink : Palette.paper, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(on ? Palette.ink : (dashed ? Palette.hairline : Palette.line),
                                           style: StrokeStyle(lineWidth: 1, dash: dashed && !on ? [4, 3] : []))
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var picked: Reason? = .kids
    @Previewable @State var words = ""
    @Previewable @FocusState var typing: Bool
    ReasonPicker(picked: $picked, words: $words, typing: $typing)
        .padding(28)
        .background(Palette.bone)
}
