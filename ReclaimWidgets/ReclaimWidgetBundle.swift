import WidgetKit
import SwiftUI

@main
struct ReclaimWidgetBundle: WidgetBundle {
    var body: some Widget {
        liveActivity
        // Controls arrived in iOS 18. The app's floor is 17, so this is the
        // one thing in the bundle that isn't always there.
        if #available(iOS 18.0, *) {
            SetItDownControl()
        }
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
