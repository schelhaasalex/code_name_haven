import SwiftUI
import ReclaimKit

@main
struct ReclaimApp: App {
    @State private var state: AppState

    init() {
        #if DEBUG
        // The "Reclaim (Sample data)" scheme: the whole app against the canvas
        // household, in memory, signed in, no network. Not in a release build.
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            let repo = PreviewRepository.sampleHousehold()
            _state = State(initialValue: AppState(repo: repo))
            IntentEnvironment.repository = repo
            return
        }
        #endif
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
