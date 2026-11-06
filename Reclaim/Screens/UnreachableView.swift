import SwiftUI
import ReclaimKit

/// The first launch with no network. There is no sign-in — an account is made
/// silently — but making it needs the internet, once. Coming back to the app
/// tries again on its own; the button is for someone who'd rather not wait.
struct UnreachableView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("app.name"))
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 22) {
                Text(t("unreachable.headline")).font(Type.hero).foregroundStyle(Palette.ink)
                Text(t("unreachable.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            }
            Spacer(minLength: 24)
            PrimaryButton(title: t("unreachable.retry")) { Task { await state.load() } }
        }
        .ground()
    }
}

#Preview {
    UnreachableView().environment(AppState(repo: PreviewRepository()))
}
