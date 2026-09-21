import SwiftUI
import ReclaimKit

@main
struct ReclaimApp: App {
    @State private var state: AppState

    init() {
        let repo = SupabaseRepository()
        let transport = SupabaseCeremonyTransport(client: repo.client)
        let state = AppState(repo: repo, transport: transport)
        _state = State(initialValue: state)

        // So Siri, the Action Button, a Shortcut and the Live Activity's End
        // button work without booting the SwiftUI stack.
        IntentEnvironment.repository = repo
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .task {
                    await state.load()
                    await state.computeInterruption()
                    await Notifications.reschedule(for: state.profile)
                }
                .onOpenURL { url in
                    Task { await URLRouter.handle(url, state: state) }
                }
        }
    }
}

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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, state.phase == .ready else { return }
            Task {
                await state.load()
                await state.computeInterruption()
            }
        }
    }
}
