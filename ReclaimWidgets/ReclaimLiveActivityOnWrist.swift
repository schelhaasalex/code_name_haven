import SwiftUI
import WidgetKit

/// The Live Activity, offered to a paired Watch as well.
///
/// From iOS 18 a Watch shows an iPhone's Live Activity in its Smart Stack by
/// itself, built from the Dynamic Island's compact pieces — the ring and a
/// bare number. Asking for the small family gives it a face of its own
/// instead. The modifier is iOS 18's, and the app's floor is 17, so this is
/// the same activity registered a second way rather than a second activity.
@available(iOS 18.0, *)
struct ReclaimLiveActivityOnWrist: Widget {
    var body: some WidgetConfiguration {
        ReclaimLiveActivity().body
            .supplementalActivityFamilies([.small])
    }
}
