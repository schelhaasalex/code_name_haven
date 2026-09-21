import SwiftUI
import ReclaimKit

/// Screens 13, 14, 18 and 20 — the four you never navigate to. They appear over
/// Home when there's something to say, at most one per launch.
struct InterruptionSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let interruption: AppState.Interruption

    var body: some View {
        Group {
            switch interruption {
            case .autoClosed(let session):   autoClosed(session)
            case .rhythmEnded(let rhythm):   rhythmEnded(rhythm)
            case .countThat(let from, let to): countThat(from: from, to: to)
            case .makeItOneTap:              oneTap
            }
        }
        .ground()
    }

    // Screen 13. Credits AT THE CAP, not at the nine hours the phone actually
    // sat there. The only correction offered is downward.
    private func autoClosed(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("autoclosed.eyebrow"))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 22) {
                Text(t("autoclosed.headline")).font(Type.display(44)).foregroundStyle(Palette.ink)
                Text(t("autoclosed.body", "time", time(session.startedAt)))
                    .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.placeName ?? t("docked.where.unnamed"))
                            .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink)
                        Text(t("autoclosed.capped")).font(Type.note).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text(Say.duration(minutes: session.durationMinutes ?? 180))
                        .font(Type.display(28)).foregroundStyle(Palette.ink)
                }
                .padding(18)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1) }

                Text(t("autoclosed.counts")).font(Type.display(21)).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                PrimaryButton(title: t("autoclosed.accept")) { dismiss() }
                Button(t("autoclosed.remove")) {
                    Task { try? await state.repo.delete(session: session.id); dismiss() }
                }
                .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.muted)
                .frame(minHeight: 48)
            }
        }
    }

    // Screen 14. The days already banked never disappear.
    private func rhythmEnded(_ rhythm: Rhythm) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("rhythmended.eyebrow"))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("rhythmended.headline")).font(Type.display(46)).foregroundStyle(Palette.ink)
                    Text(t("rhythmended.subhead")).font(Type.display(26)).foregroundStyle(Palette.clay)
                }
                Text(t("rhythmended.body", "count", Say.number(rhythm.longestRunDays)))
                    .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            }
            Spacer(minLength: 20)
            VStack(spacing: 18) {
                PrimaryButton(title: t("rhythmended.primary")) {
                    dismiss(); Task { await state.setItDown() }
                }
                Text(t("rhythmended.footer")).font(Type.body(14))
                    .foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
            }
        }
    }

    // Screen 18. Always solo and placeless: nobody was broadcasting, so
    // co-presence cannot be reconstructed afterwards and must not be invented.
    private func countThat(from: Date, to: Date) -> some View {
        let minutes = Int(to.timeIntervalSince(from) / 60)
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("countthat.eyebrow"))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 22) {
                Text(t("countthat.headline", "duration", Say.spokenDuration(minutes: minutes)))
                    .font(Type.display(44)).foregroundStyle(Palette.ink)
                Text(t("countthat.body", "time", time(from)))
                    .font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("docked.where.unnamed"))
                            .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.ink2)
                        Text("\(time(from)) until \(time(to))")
                            .font(Type.note).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text(Say.duration(minutes: minutes))
                        .font(Type.display(28)).foregroundStyle(Palette.ink)
                }
                .padding(18)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1) }
            }
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                PrimaryButton(title: t("countthat.accept")) {
                    Task {
                        _ = try? await state.repo.recordRetroactive(from: from, to: to)
                        await state.load(); dismiss()
                    }
                }
                Button(t("countthat.decline")) { dismiss() }
                    .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.muted)
                    .frame(minHeight: 48)
                Text(t("countthat.footer")).font(Type.note)
                    .foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
        }
    }

    // Screen 20. Must NOT read as setup. Declining is permanent.
    private var oneTap: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("onetap.eyebrow"))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 24) {
                Text(t("onetap.headline")).font(Type.display(42)).foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(1...3, id: \.self) { i in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(i)")
                                .font(Type.body(13, weight: .semibold))
                                .frame(width: 26, height: 26)
                                .background(Palette.linen, in: Circle())
                                .foregroundStyle(Palette.ink2)
                            Text(t("onetap.step.\(i)"))
                                .font(Type.body(15)).foregroundStyle(Palette.ink2)
                        }
                    }
                }
                Text(t("onetap.body")).font(Type.body(14))
                    .foregroundStyle(Palette.muted).lineSpacing(3)
            }
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                PrimaryButton(title: t("onetap.primary")) {
                    OneTapOffer.hasBeenOffered = true; dismiss()
                }
                Button(t("onetap.decline")) {
                    OneTapOffer.hasBeenOffered = true; dismiss()
                }
                .font(Type.body(15, weight: .medium)).foregroundStyle(Palette.muted)
                .frame(minHeight: 48)
                Text(t("onetap.footer")).font(Type.note)
                    .foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
