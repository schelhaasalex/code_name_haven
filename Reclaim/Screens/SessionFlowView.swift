import SwiftUI
import ReclaimKit

/// Screens 3, 5 and 6 are ONE view driven by session state, not three
/// navigation destinations — so the session survives backgrounding and there is
/// never a back button out of the middle of a ceremony.
struct SessionFlowView: View {
    @Environment(AppState.self) private var state
    @State private var step: Step = .docked

    enum Step { case docked, countUp, live }

    var body: some View {
        Group {
            switch step {
            case .docked:  DockedView { step = .countUp }
            case .countUp: CountUpView { step = .live }
            case .live:    SessionView(onEnd: { Task { await state.end() } })
            }
        }
        .animation(.easeInOut(duration: 0.4), value: step)
        .task {
            // Straight to the ceremony when you joined someone else's — the
            // "where is this?" question is already answered by theirs.
            if state.gathering?.placeId != nil { step = .countUp }
        }
    }

}

#Preview {
    SessionFlowView().environment(AppState(repo: PreviewRepository()))
}
