import SwiftUI
import ReclaimKit

/// Screens 3, 5, 6 and 8 are ONE view driven by session state, not four
/// navigation destinations — so the session survives backgrounding and there is
/// never a back button out of the middle of a ceremony.
struct SessionFlowView: View {
    @Environment(AppState.self) private var state
    @State private var step: Step = .docked
    @State private var ended: Ended?

    enum Step { case docked, countUp, live }
    struct Ended: Equatable { let minutes: Int; let people: Int; let place: String? }

    var body: some View {
        Group {
            if let ended {
                SessionEndView(minutes: ended.minutes, people: ended.people, place: ended.place)
            } else {
                switch step {
                case .docked:  DockedView { step = .countUp }
                case .countUp: CountUpView { step = .live }
                case .live:    SessionView(onEnd: finish)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: step)
        .task {
            // Straight to the ceremony when you joined someone else's — the
            // "where is this?" question is already answered by theirs.
            if state.gathering?.placeId != nil { step = .countUp }
        }
    }

    private func finish() {
        let minutes = Int(Date().timeIntervalSince(state.startedAt ?? .now) / 60)
        let people = max(1, state.members.count)
        let place = state.placeName
        Task {
            await state.end()
            ended = Ended(minutes: max(0, minutes), people: people, place: place)
        }
    }
}

#Preview {
    SessionFlowView().environment(AppState(repo: PreviewRepository()))
}
