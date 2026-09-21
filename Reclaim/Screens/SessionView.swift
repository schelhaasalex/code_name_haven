import SwiftUI
import ReclaimKit

/// Screens 6 and 12. In session — with five people, or with one.
///
/// Solo is deliberately the SAME view rather than a degraded variant: the
/// parallel construction is the statement. Solo has to carry v1, because the
/// network doesn't exist yet.
struct SessionView: View {
    @Environment(AppState.self) private var state
    let onEnd: () -> Void

    @State private var elapsed: TimeInterval = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var solo: Bool { state.members.count <= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: state.placeName ?? t("docked.where.unnamed"),
                    mark: Palette.ember, tint: Palette.dust)

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 12) {
                Text(Say.clock(elapsed))
                    .font(Type.timer)
                    .foregroundStyle(Palette.cream)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(solo ? t("session.count.solo")
                          : t("session.count", "count", Say.count(state.members.count)))
                    .font(Type.body(18)).foregroundStyle(Palette.dust)
            }

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 22) {
                Text(solo ? t("session.line.solo") : t("session.line"))
                    .font(Type.display(20)).foregroundStyle(Palette.dust)
                QuietButton(title: t("session.end"), night: true, action: onEnd)
            }
        }
        .ground(night: true)
        .background(alignment: .leading) { rings }
        .onReceive(tick) { _ in
            elapsed = Date().timeIntervalSince(state.startedAt ?? .now)
        }
    }

    private var rings: some View {
        ZStack {
            Circle().stroke(Palette.ember.opacity(0.16), lineWidth: 1)
                .frame(width: 460, height: 460).offset(x: -35, y: 60)
            Circle().stroke(Palette.ember.opacity(0.09), lineWidth: 1)
                .frame(width: 620, height: 620).offset(x: -115, y: -20)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Together") {
    SessionView(onEnd: {}).environment(AppState(repo: PreviewRepository()))
}

#Preview("Just you") {
    SessionView(onEnd: {}).environment(AppState(repo: PreviewRepository(
        members: [Member(profileId: PreviewRepository.me, displayName: "Alex", stillLive: true)])))
}
