import Foundation
import ReclaimKit

/// Where a tapped NFC tag lands.
///
/// The tag carries an https universal link, not a custom scheme, because iOS
/// only offers to open http(s) URLs from a BACKGROUND tag read — which is the
/// whole point: the phone stays locked and the app stays closed.
enum URLRouter {

    /// The same link, arriving by both doors at once, is one tap.
    @MainActor private static var last: (url: URL, at: Date)?

    @MainActor
    static func handle(_ url: URL, state: AppState) async {
        if let last, last.url == url, Date().timeIntervalSince(last.at) < 3 { return }
        last = (url, Date())
        // An invite joins a place and starts nothing — checked first, and a
        // different path from a card, so the two can't be mistaken.
        if let token = Links.inviteToken(from: url) {
            await state.accept(inviteToken: token)
            return
        }
        // A slot in the box: never an unknown card — a new box's place is
        // made by the first phone into it.
        if let dock = Dock.link(from: url) {
            await state.dock(dock)
            return
        }
        guard let secret = Handle.secret(fromCardURL: url) else { return }
        guard let place = try? await state.repo.resolvePlace(secret: secret) else {
            state.banner = t("error.card")
            return
        }
        // Already down: the card says where, it doesn't start a second evening.
        if state.isLive {
            await state.moveHere(place)
        } else {
            await state.setItDown(place: place, source: .tag)
        }
    }
}
