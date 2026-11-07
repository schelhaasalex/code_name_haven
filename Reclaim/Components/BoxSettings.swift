import SwiftUI
import ReclaimKit

/// One box in Settings: its name — a field for whoever first read it, words
/// for everyone else — and the way to let it go.
struct BoxSettings: View {
    let name: String
    let canRename: Bool
    let onRename: (String) -> Void
    let onForget: () -> Void
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if canRename {
                TextField(name, text: $draft)
                    .font(Type.body(16)).foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !draft.trimmed.isEmpty, draft.trimmed != name else { return }
                        onRename(draft.trimmed)
                    }
                    .paperCard()
            } else {
                Text(name).font(Type.body(16)).foregroundStyle(Palette.ink)
            }
            TextAction(title: t("settings.forget"), tint: Palette.ink2, action: onForget)
        }
        .task(id: name) { draft = name }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        BoxSettings(name: t("box.default.1"), canRename: true, onRename: { _ in }, onForget: {})
        BoxSettings(name: t("box.default.2"), canRename: false, onRename: { _ in }, onForget: {})
    }
    .padding()
    .background(Palette.bone)
}
