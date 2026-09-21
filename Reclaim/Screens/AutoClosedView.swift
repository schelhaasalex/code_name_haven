import SwiftUI
import ReclaimKit

/// Screen 13. Credits AT THE CAP, not at the nine hours the phone actually sat
/// there — otherwise the cheapest strategy in the product is to start a session
/// and walk away, and hours reclaimed turns to noise.
///
/// The only correction offered is downward.
struct AutoClosedView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("autoclosed.eyebrow"))
            Spacer(minLength: 20)
            body(for: session)
            Spacer(minLength: 20)
            actions
        }
        .ground()
    }

    private func body(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(t("autoclosed.headline"))
                .font(Type.display(44)).foregroundStyle(Palette.ink)
            Text(t("autoclosed.body", "time", session.startedAt.shortTime))
                .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            PaperCard {
                StatRow(title: state.placeName ?? t("docked.where.unnamed"),
                        subtitle: t("autoclosed.capped"),
                        value: Say.duration(minutes: session.durationMinutes ?? 180))
            }
            Text(t("autoclosed.counts"))
                .font(Type.display(21)).foregroundStyle(Palette.ink2)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: t("autoclosed.accept")) { dismiss() }
            TextAction(title: t("autoclosed.remove")) {
                Task {
                    try? await state.repo.delete(session: session.id)
                    await state.load()
                    dismiss()
                }
            }
        }
    }
}
