import Foundation
import ReclaimKit

/// Where a tapped NFC tag lands.
///
/// The tag carries an https universal link, not a custom scheme, because iOS
/// only offers to open http(s) URLs from a BACKGROUND tag read — which is the
/// whole point: the phone stays locked and the app stays closed.
enum URLRouter {
    @MainActor
    static func handle(_ url: URL, state: AppState) async {
        guard let secret = Handle.secret(fromCardURL: url) else { return }
        guard let place = try? await state.repo.resolvePlace(secret: secret) else {
            state.banner = t("error.card")
            return
        }
        await state.setItDown(place: place, source: .tag)
    }
}
