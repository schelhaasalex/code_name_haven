import SwiftUI
import ReclaimKit

/// What the window shows: the evening if one is running, Home if not. There is
/// no tab bar, no sign-in and no back button out of an evening — the shape of
/// the app is this switch.
struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashDone = false

    var body: some View {
        Group {
            switch state.phase {
            case .loading:
                ZStack { Palette.bone.ignoresSafeArea() }
            case .unreachable:
                UnreachableView()
            case .ready:
                if let ended = state.justEnded {
                    SessionEndView(ended: ended)
                } else if state.isLive {
                    SessionView()
                } else {
                    HomeView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: state.isLive)
        .animation(.easeInOut(duration: 0.45), value: state.justEnded)
        // Screen 0, over the top rather than in the switch: the splash is on a
        // clock of its own and holds nothing up. Everything below it is already
        // loading, already live, already reachable.
        .overlay {
            if !splashDone {
                SplashView { splashDone = true }
            }
        }
        // Screen 13, the one thing that waits over Home: an evening the server
        // closed for you.
        .sheet(item: Binding(get: { state.isLive ? nil : state.closedForYou },
                             set: { _ in state.dismissClosedForYou() })) {
            AutoClosedView(session: $0)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, state.phase != .loading else { return }
            Task { await state.load() }
        }
    }
}

#Preview {
    RootView().environment(AppState(repo: PreviewRepository()))
}
