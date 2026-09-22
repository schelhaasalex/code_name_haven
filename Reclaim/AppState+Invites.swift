import Foundation
import ReclaimKit

/// Bringing someone into a place from a distance, and being brought in.
///
/// An invite joins a place and starts nothing (migration 0008). Screen 4's
/// realtime `Invitation` is a different thing — "someone just set theirs down"
/// — which is why everything here says invite.
@MainActor
extension AppState {

    /// A place made so there's something to invite someone to — day one,
    /// before any evening has one. Chosen, never required.
    public func makePlace(named name: String) async -> Place? {
        let secret = Handle.newSecret()
        do {
            let id = try await repo.createPlace(handle: Handle.generate(), secret: secret, name: name)
            PlaceSecrets.save(secret, for: id)
            await reloadPlaces()
            if !isLive { watchPlaces() }
            return places.first { $0.id == id }
        } catch {
            banner = t("error.retry")
            return nil
        }
    }

    /// A fresh week-long link into `place`.
    public func inviteLink(to place: UUID) async -> URL? {
        do {
            return Links.inviteURL(token: try await repo.createInvite(place: place))
        } catch {
            banner = t("error.retry")
            return nil
        }
    }

    /// Opening an invite. Signed out, it waits until you're in — the link
    /// shouldn't have to be tapped twice because sign-in came between.
    public func accept(inviteToken token: String) async {
        guard phase == .ready else { pendingInvite = token; return }
        do {
            joinedPlace = try await repo.acceptInvite(token: token)
            await reloadPlaces()
            hasCompany = true
            if !isLive { watchPlaces() }
        } catch {
            banner = t("error.invite")
        }
    }
}
