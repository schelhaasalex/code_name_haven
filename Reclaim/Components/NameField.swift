import SwiftUI
import ReclaimKit

/// A name that can be changed, and looks it: a pencil at rest, a clay edge
/// and a way to clear it while typing, and a check for a moment once it's
/// saved. Tapping anywhere on it starts editing. It had been a field drawn
/// exactly like the card of numbers beneath it, and nobody could tell.
struct NameField: View {
    @Binding var text: String
    let placeholder: String
    /// Saved a moment ago: the pencil is a check until this goes false.
    var saved: Bool = false
    var editing: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .font(Type.body(16)).foregroundStyle(Palette.ink)
                .focused(editing)
                .submitLabel(.done)
                .onSubmit(onSubmit)
            trailing
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 56)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(editing.wrappedValue ? Palette.clay : Palette.line,
                        lineWidth: editing.wrappedValue ? 1.5 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { editing.wrappedValue = true }
        .animation(.easeInOut(duration: 0.2), value: editing.wrappedValue)
        .animation(.easeInOut(duration: 0.25), value: saved)
    }

    @ViewBuilder private var trailing: some View {
        if editing.wrappedValue {
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 17))
                        .foregroundStyle(Palette.hairline)
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("box.name.clear"))
                .transition(.opacity)
            }
        } else {
            Image(systemName: saved ? "checkmark" : "pencil")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(saved ? Palette.clay : Palette.muted)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    @Previewable @State var name = "The Harbor"
    @Previewable @FocusState var editing: Bool
    VStack(spacing: 16) {
        NameField(text: $name, placeholder: "The Harbor", editing: $editing) {}
        NameField(text: .constant("Harbor House"), placeholder: "", saved: true, editing: $editing) {}
    }
    .padding()
    .background(Palette.bone)
}
