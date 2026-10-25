import WidgetKit
import SwiftUI

@main
struct ReclaimWidgetBundle: WidgetBundle {
    var body: some Widget {
        // One activity either way: on 18 it also has a face for the Watch.
        if #available(iOS 18.0, *) {
            ReclaimLiveActivityOnWrist()
        } else {
            ReclaimLiveActivity()
        }
        // Controls arrived in iOS 18. The app's floor is 17, so this is the
        // one thing in the bundle that isn't always there.
        if #available(iOS 18.0, *) {
            SetItDownControl()
        }
    }
}
