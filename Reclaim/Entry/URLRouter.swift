import Foundation
import ReclaimKit

/// Where a box's tag, or its code, lands.
///
/// Both carry an https universal link, not a custom scheme, because iOS only
/// offers to open http(s) URLs from a BACKGROUND tag read — the phone stays
/// locked and the app stays closed — and the camera opens them the same way.
enum URLRouter {

    /// The same link, arriving by both doors at once, is one read.
    @MainActor private static var last: (url: URL, at: Date)?

    @MainActor
    static func handle(_ url: URL, state: AppState) async {
        if let last, last.url == url, Date().timeIntervalSince(last.at) < 3 { return }
        last = (url, Date())
        guard let link = Dock.link(from: url) else { return }
        await state.dock(link)
    }
}
