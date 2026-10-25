import SwiftUI
import WidgetKit
import ReclaimKit

/// Tonight, on the wrist, while the phone is somewhere else — in the box, face
/// down, in a pocket. The Watch shows it in the Smart Stack; nothing about it
/// is set up on the Watch.
///
/// The lock screen's rules, smaller. No ticking digits: a wrist is glanced at
/// far more often than a face-down phone is picked up, so a counter here would
/// be the clock the evening was meant to put away. The ring fills once over
/// the first fifteen minutes and stops. No End button — the wrist is for
/// looking, and the lock screen and the app still end the evening.
struct WristActivity: View {
    let state: ReclaimActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            RingMark(startedAt: state.startedAt, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(Type.display(16))
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(t("wrist.since", "time", Say.time(state.startedAt)))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.dust)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// The same headline as everywhere else the evening shows.
    private var headline: String {
        state.memberCount <= 1 ? t("lockscreen.solo")
                               : t("lockscreen.together", "count", Say.count(state.memberCount))
    }
}
