import SwiftUI
import ReclaimKit

/// Screen 13. Credits AT THE CAP, not at the nine hours the phone actually sat
/// there — otherwise the cheapest strategy in the product is to start a session
/// and walk away, and hours reclaimed turns to noise.
///
/// The only correction offered is downward.
///
/// It names the box this evening was at and when it was, from the session
/// itself: the box Home leads with may be a different one, and a phone left
/// in at two in the afternoon wasn't left in last night.
struct AutoClosedView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let session: Session
    /// The evening's own box, once its gathering has said which.
    @State private var place: String?
    @State private var removing = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: Say.partOfDay(session.startedAt))
            Spacer(minLength: 20)
            body(for: session)
            Spacer(minLength: 20)
            actions
        }
        .ground()
        .task { place = await state.placeName(ofGathering: session.gatheringId) }
    }

    private func body(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(t("autoclosed.headline"))
                .font(Type.display(44)).foregroundStyle(Palette.ink)
            Text(t("autoclosed.body", "time", session.startedAt.shortTime))
                .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            PaperCard {
                StatRow(title: place ?? t("box.yours"),
                        subtitle: t("autoclosed.capped"),
                        value: Say.duration(minutes: session.durationMinutes ?? AutoClosed.capMinutes))
            }
            Text(t("autoclosed.counts"))
                .font(Type.display(21)).foregroundStyle(Palette.ink2)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: t("autoclosed.accept")) { dismiss() }
            // Stays open if the removing didn't go through: closing would
            // say it had, and the day would still be in the sky.
            TextAction(title: t(failed ? "error.retry" : "autoclosed.remove"),
                       tint: failed ? Palette.clay : Palette.muted) {
                guard !removing else { return }
                removing = true
                Task {
                    do {
                        try await state.repo.delete(session: session.id)
                        await state.load()
                        dismiss()
                    } catch {
                        failed = true
                    }
                    removing = false
                }
            }
            .opacity(removing ? 0.5 : 1)
        }
    }
}

#Preview {
    AutoClosedView(session: PreviewRepository.autoClosedSession)
        .environment(AppState(repo: PreviewRepository()))
}
