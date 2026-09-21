import SwiftUI
import ReclaimKit

/// Screen 3. The moment after the tap.
///
/// Goes dark immediately, which is also the right physical cue as the phone
/// turns over. It is ALREADY COUNTING — nothing is gated behind saying where
/// you are, and a session with no place counts exactly the same.
struct DockedView: View {
    @Environment(AppState.self) private var state
    let onwards: () -> Void

    @State private var elapsed: TimeInterval = 0
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(t("docked.where.label")).eyebrow(Palette.dust)
                        Spacer()
                        Text(state.placeName ?? t("docked.where.unnamed"))
                            .font(Type.display(24))
                            .foregroundStyle(state.placeName == nil ? Palette.dim : Palette.cream)
                    }
                    Text(t("docked.where.body"))
                        .font(Type.body(14)).foregroundStyle(Palette.dust).lineSpacing(3)

                    QuietButton(title: t("docked.scan"), night: true) { /* NFC scan */ }
                }
                .padding(20)
                .background(Color(hex: 0x1E1A14), in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0x332B22), lineWidth: 1) }

                Text(t("docked.footer"))
                    .font(Type.note).foregroundStyle(Palette.dim)
                    .frame(maxWidth: .infinity)
            }
        }
        .ground(night: true)
        .onReceive(tick) { _ in
            elapsed = Date().timeIntervalSince(state.startedAt ?? .now)
            if elapsed > 4 { onwards() }
        }
        .onTapGesture { onwards() }
    }
}

#Preview {
    DockedView(onwards: {}).environment(AppState(repo: PreviewRepository()))
}
