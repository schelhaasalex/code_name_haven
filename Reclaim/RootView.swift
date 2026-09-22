import SwiftUI
import ReclaimKit

/// What the window shows: the ritual if one is running, Home if not, Welcome if
/// nobody is signed in. There is no tab bar and no back button out of a
/// session — the shape of the app is this switch.
struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashDone = false

    var body: some View {
        Group {
            switch state.phase {
            case .loading:
                ZStack { Palette.bone.ignoresSafeArea() }
            case .signedOut:
                WelcomeView()
            case .ready:
                if let ended = state.justEnded {
                    SessionEndView(startedAt: ended.startedAt, minutes: ended.minutes,
                                   people: ended.people, place: ended.place)
                } else if state.isLive {
                    SessionFlowView()
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
        // An invitation cuts the splash short rather than waiting it out. It is
        // the one thing in the product that interrupts, it is worth interrupting
        // for, and two seconds of branding is two seconds of someone across the
        // table having already put theirs down.
        .onChange(of: state.invitation != nil) { _, arrived in
            if arrived { splashDone = true }
        }
        // Screen 4 covers whatever you were looking at, because the whole
        // point is that it reaches you across the room.
        .sheet(item: Binding(get: { state.joinedPlace },
                             set: { _ in state.joinedPlace = nil })) {
            JoinedPlaceView(joined: $0)
        }
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
