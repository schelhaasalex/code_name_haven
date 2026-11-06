import SwiftUI
import ReclaimKit

@main
struct ReclaimApp: App {
    @State private var state: AppState

    init() {
        #if DEBUG
        // The "Reclaim (Sample data)" scheme: the whole app against the canvas
        // household and its box, in memory, no network. Not in a release build.
        // `xcrun simctl openurl booted reclaim://d/any/1` puts a phone in it.
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            _state = State(initialValue: AppState(repo: PreviewRepository.sampleHousehold(),
                                                 boxPlace: PreviewRepository.kitchenTable))
            return
        }
        #endif
        let state = AppState(repo: SupabaseRepository())
        _state = State(initialValue: state)
        // Here, not in a view: when the box relaunches the app in the
        // background there is no view, and the connection iOS kept open has
        // to be claimed before launch finishes.
        state.watchBox()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .task { await state.load() }
                .onOpenURL { url in
                    Task { await URLRouter.handle(url, state: state) }
                }
                // A tag read by the system arrives as an activity to
                // continue, not a URL to open — `onOpenURL` never sees it.
                // The app came forward on every tap and did nothing.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    Task { await URLRouter.handle(url, state: state) }
                }
        }
    }
}
