import SwiftUI
import WidgetKit

/// Which face the activity shows: the lock screen's, or — when a paired Watch
/// asks for the small family — the wrist's.
@available(iOS 18.0, *)
struct ActivityFace<LockScreen: View>: View {
    let lockScreen: LockScreen
    let wrist: WristActivity

    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: wrist
        default: lockScreen
        }
    }
}
