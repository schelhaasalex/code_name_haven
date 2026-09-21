import SwiftUI
import ReclaimKit

/// Screen 18 — the answer to "do I have to remember to start it?"
///
/// Always solo and always placeless: nobody was broadcasting, so co-presence
/// cannot be reconstructed after the fact and must not be invented.
///
/// The sensor OFFERS. It never asserts, and declining is one tap.
struct CountThatView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let from: Date
    let to: Date

    private var minutes: Int { Int(to.timeIntervalSince(from) / 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("countthat.eyebrow"))
            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 22) {
                Text(t("countthat.headline", "duration", Say.spokenDuration(minutes: minutes)))
                    .font(Type.display(44)).foregroundStyle(Palette.ink)
                Text(t("countthat.body", "time", from.shortTime))
                    .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
                PaperCard {
                    StatRow(title: t("docked.where.unnamed"),
                            subtitle: t("countthat.window",
                                       "from", from.shortTime, "to", to.shortTime),
                            value: Say.duration(minutes: minutes))
                }
            }

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                PrimaryButton(title: t("countthat.accept")) {
                    Task {
                        _ = try? await state.repo.recordRetroactive(from: from, to: to)
                        await state.load()
                        dismiss()
                    }
                }
                TextAction(title: t("countthat.decline")) { dismiss() }
                Text(t("countthat.footer"))
                    .font(Type.note).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
        }
        .ground()
    }
}

#Preview {
    CountThatView(from: .now.addingTimeInterval(-9000), to: .now.addingTimeInterval(-1200))
        .environment(AppState(repo: PreviewRepository()))
}
