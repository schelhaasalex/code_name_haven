import SwiftUI
import ReclaimKit

/// The first launch with no network. There is no sign-in — an account is made
/// silently — but making it needs the internet, once. It tries again by itself
/// the moment the network comes back, and on every return to the app; the
/// button is for someone who'd rather not wait, and goes quiet while a try is
/// under way, so a tap with no network doesn't look like nothing happened.
struct UnreachableView: View {
    @Environment(AppState.self) private var state
    @State private var trying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("app.name"))
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 22) {
                Text(t("unreachable.headline")).font(Type.hero).foregroundStyle(Palette.ink)
                Text(t("unreachable.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            }
            Spacer(minLength: 24)
            PrimaryButton(title: t(trying ? "unreachable.trying" : "unreachable.retry")) {
                Task { await retry() }
            }
            .disabled(trying)
            .opacity(trying ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.2), value: trying)
        }
        .ground()
        .task {
            for await _ in NetworkWatch.reachable() { await retry() }
        }
    }

    /// One try at a time: the network coming back and a tap can arrive
    /// together.
    private func retry() async {
        guard !trying else { return }
        trying = true
        await state.load()
        trying = false
    }
}

#Preview {
    UnreachableView().environment(AppState(repo: PreviewRepository()))
}
