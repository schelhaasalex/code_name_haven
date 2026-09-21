import SwiftUI
import ReclaimKit

/// What the window shows: the ritual if one is running, Home if not, Welcome if
/// nobody is signed in. There is no tab bar and no back button out of a
/// session — the shape of the app is this switch.
struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch state.phase {
            case .loading:
                ZStack { Palette.bone.ignoresSafeArea() }
            case .signedOut:
                WelcomeView()
            case .ready:
                if state.isLive {
                    SessionFlowView()
                } else {
                    HomeView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: state.isLive)
        // Screen 4 covers whatever you were looking at, because the whole
        // point is that it reaches you across the room.
        .fullScreenCover(item: Binding(get: { state.invitation },
                                       set: { _ in state.dismissInvitation() })) {
            JoinInviteView(invitation: $0)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, state.phase == .ready else { return }
            Task {
                await state.load()
                await state.computeInterruption()
            }
        }
    }
}

#Preview {
    RootView().environment(AppState(repo: PreviewRepository()))
}
