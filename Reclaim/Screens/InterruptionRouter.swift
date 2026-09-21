import SwiftUI
import ReclaimKit

/// Screens 13, 14, 18 and 20 — the four you never navigate to. They appear over
/// Home when there's something to say, at most one per launch, and each one is
/// its own file.
struct InterruptionRouter: View {
    let interruption: AppState.Interruption

    var body: some View {
        switch interruption {
        case .autoClosed(let session):     AutoClosedView(session: session)
        case .rhythmEnded(let rhythm):     RhythmEndedView(rhythm: rhythm)
        case .countThat(let from, let to): CountThatView(from: from, to: to)
        case .makeItOneTap:                OneTapView()
        }
    }
}
