import SwiftUI
import WidgetKit
import ReclaimKit

/// Tonight, on the wrist, while the phone is somewhere else — in the box, face
/// down, in a pocket. The Watch shows it in the Smart Stack; nothing about it
/// is set up on the Watch.
///
/// The evening charges here: the ring steps through its four segments and
/// the headline with it — Settling in, Tonight counts, Unwinding, Present,
/// Recharged — each pushed by the server as it's reached. No ticking digits,
/// and nothing that creeps: four changes in an evening is a mark, not a timer.
/// No End button — the wrist is for looking, and the lock screen and the app
/// still end the evening.
struct WristActivity: View {
    let state: ReclaimActivityAttributes.ContentState
    /// Past the cap with no ending pushed: the server has closed it.
    var stale = false

    var body: some View {
        HStack(spacing: 10) {
            RingMark(stage: state.stage, memberCount: state.memberCount, size: 30)
                .opacity(stale ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(Type.display(16))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(since)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dust)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Where the evening has got to. The count moves to the line below.
    private var headline: String {
        stale ? t("lockscreen.closed") : EveningCharge.line(stage: state.stage)
    }

    private var since: String {
        let time = Say.time(state.startedAt)
        return state.memberCount <= 1 ? t("wrist.since", "time", time)
                                      : t("evening.together", "count", Say.count(state.memberCount), "time", time)
    }
}
