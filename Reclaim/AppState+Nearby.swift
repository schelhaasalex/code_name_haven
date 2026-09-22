import Foundation
import ReclaimKit

/// Phone to phone: joining the evening of the phone already face down on the
/// table, with no card, no link and nothing to set up.
///
/// The two halves are deliberately lopsided. The phone that is DOWN keeps
/// talking in the background, because that is where it is. The phone still in
/// your HAND listens only while you are holding it — the moment this is for is
/// the one before you put it down, and scanning all evening would spend
/// battery to hear yourself.
///
/// Nothing here can start an evening. The radio's whole output is a question
/// on screen 4 (rule 4), and Bluetooth being off, refused or absent changes
/// nothing else about the ritual (rule 7).
@MainActor
extension AppState {

    /// Your evening, findable by the phones around it. Called when one starts
    /// and again when one moves to a place, because a placeless evening has
    /// no key — there is nothing to join yet.
    func beFindable() async {
        // A failed call and a truthful "nothing to advertise" flatten into the
        // same nil here, and mean the same thing to this phone: stay quiet.
        guard let key = try? await repo.openNearby() else { return }
        beacon.start(key: key)
    }

    /// Listening, while you are holding the phone and nothing is running.
    /// Starts nothing on its own: `NearbyScanner` stays silent until the
    /// person has been asked about Bluetooth, which happens at the dock.
    func listenNearby() {
        guard !isLive else { return }
        scanner.start { [weak self] key in
            guard let self else { return }
            Task { await self.heard(key) }
        }
    }

    func stopListeningNearby() {
        scanner.stop()
    }

    /// A key off the air is worth whatever the server says it is worth —
    /// which may be nothing: the evening ended, the phone belongs to someone
    /// already at your table, or what came back wasn't ours at all.
    private func heard(_ key: String) async {
        guard !isLive, offers.firstSight(of: key) else { return }
        guard let invitation = try? await repo.nearbyOffer(key: key) else { return }
        await offer(invitation)
    }

    /// Screen 4's button, for the offer that came over the air. The key turns
    /// into a place inside the database and never comes back as one, so a
    /// phone that only listened is left holding nothing it could use tomorrow.
    func joinNearby(_ key: String) async {
        do {
            let to = try await repo.joinNearby(key: key)
            guard let s = try await repo.liveSession() else { return }
            if session == nil {
                Sensation.docked()
                await adopt(session: s, at: Date(), announcing: true)
            } else {
                // An evening of your own, moved to the table you walked up to
                // rather than split in two (migration 0007). Your start time
                // doesn't move, so nothing about what counted changes.
                session = s
                gathering = try? await repo.gathering(to)
                await learnPlace(of: gathering)
                await refreshMembers()
                Sensation.joined()
            }
        } catch {
            // Including the evening ending between the offer and the tap,
            // which is not a failure worth a word of its own.
            banner = t("error.retry")
        }
    }
}
