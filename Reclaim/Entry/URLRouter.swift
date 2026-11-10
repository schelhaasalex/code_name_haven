import Foundation
import ReclaimKit

/// Where a box's code lands, read by the Camera rather than the app's own
/// scanner: an https universal link, which opens the app if it's installed
/// and the site's page if it isn't.
enum URLRouter {

    /// The same link, arriving by both doors at once, is one read.
    @MainActor private static var last: (url: URL, at: Date)?

    @MainActor
    static func handle(_ url: URL, state: AppState) async {
        #if DEBUG
        if await simulatedSlot(url, state: state) { return }
        #endif
        if let last, last.url == url, Date().timeIntervalSince(last.at) < 3 { return }
        last = (url, Date())
        guard let link = Dock.link(from: url) else { return }
        await state.dock(link)
    }

    #if DEBUG
    /// The simulator has no box and can't charge, so this stands in for one,
    /// past the question the radio asks (`Box.isThisPhone`) and through the
    /// same code from there:
    ///
    ///     xcrun simctl openurl booted reclaim://box/in/2   # into slot 2
    ///     xcrun simctl openurl booted reclaim://box/out    # out again
    ///
    /// At the box this phone last used. Debug builds only — in a release
    /// build the app's own scheme opens nothing.
    @MainActor
    private static func simulatedSlot(_ url: URL, state: AppState) async -> Bool {
        guard url.scheme == "reclaim", url.host == "box" else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch parts.first {
        case "in":
            guard let place = state.lastBox ?? state.boxPlaces.first else { return true }
            let asked = parts.dropFirst().first.flatMap { Int($0) }
            let slot = asked.map { Dock.slots.contains($0) ? $0 : 1 } ?? 1
            await state.cameIn(slot: slot, at: place)
        case "out":
            await state.leaving()
        default:
            break
        }
        return true
    }
    #endif
}
