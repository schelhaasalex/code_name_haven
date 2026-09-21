import SwiftUI
import ReclaimKit

/// Screen 3. The moment after the tap.
///
/// Goes dark immediately, which is also the right physical cue as the phone
/// turns over. It is ALREADY COUNTING — nothing is gated behind saying where
/// you are, and a session with no place counts exactly the same.
///
/// It moves on when the phone goes face down — the gesture it was drawn for —
/// or after a while if it never does. Not at four seconds, and not on any tap:
/// both made "Scan the card" a race nobody could win.
struct DockedView: View {
    @Environment(AppState.self) private var state
    let onwards: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var choosing = false
    /// Face-down is the real cue. This is for a phone left face up, or one
    /// with no accelerometer, like the simulator.
    private let fallback: TimeInterval = 20
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: t("docked.eyebrow"), mark: Palette.ember, tint: Palette.dust)
                Spacer()
                Text(Say.clock(elapsed))
                    .font(Type.display(20))
                    .foregroundStyle(Palette.ember)
                    .monospacedDigit()
            }

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 18) {
                Text(t("docked.headline")).font(Type.display(46)).foregroundStyle(Palette.cream)
                Text(t("docked.body")).font(Type.lede).foregroundStyle(Palette.dust).lineSpacing(4)
            }

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                NightCard { VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(t("docked.where.label")).eyebrow(Palette.dust)
                        Spacer()
                        Text(state.placeName ?? t("docked.where.unnamed"))
                            .font(Type.display(24))
                            .foregroundStyle(state.placeName == nil ? Palette.dim : Palette.cream)
                    }
                    // "If there isn't, it stays Somewhere" stops being true
                    // the moment it has a place.
                    Text(state.placeName == nil ? t("docked.where.body") : t("docked.where.known"))
                        .font(Type.body(14)).foregroundStyle(Palette.dust).lineSpacing(3)

                    if state.placeName == nil {
                        QuietButton(title: t("docked.scan"), night: true) { choosing = true }
                    }
                } }

                Text(t("docked.footer"))
                    .font(Type.note).foregroundStyle(Palette.dim)
                    .frame(maxWidth: .infinity)
            }
        }
        .ground(night: true)
        .sheet(isPresented: $choosing) { WhereSheet().environment(state) }
        .onReceive(tick) { _ in
            elapsed = Date().timeIntervalSince(state.startedAt ?? .now)
            if elapsed > fallback, !choosing { onwards() }
        }
        .onChange(of: state.iAmFaceDown) { _, down in
            if down { onwards() }
        }
    }
}

#Preview {
    DockedView(onwards: {}).environment(AppState(repo: PreviewRepository()))
}
