import WidgetKit
import SwiftUI

@main
struct ReclaimWidgetBundle: WidgetBundle {
    var body: some Widget {
        liveActivity
    }

    /// One activity either way: on 18 it also has a face for the Watch. Not an
    /// if/else in `body` — the bundle's builder refuses one — but a return
    /// per branch, which an opaque type allows across `#available`.
    private var liveActivity: some Widget {
        if #available(iOS 18.0, *) {
            return ReclaimLiveActivityOnWrist()
        } else {
            return ReclaimLiveActivity()
        }
    }
}
