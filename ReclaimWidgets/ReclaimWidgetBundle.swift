import WidgetKit
import SwiftUI

@main
struct ReclaimWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReclaimLiveActivity()
        // Controls arrived in iOS 18. The app's floor is 17, so this is the
        // one thing in the bundle that isn't always there.
        if #available(iOS 18.0, *) {
            SetItDownControl()
        }
    }
}
