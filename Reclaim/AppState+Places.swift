import Foundation
import ReclaimKit

/// The places half of `AppState`: where your evenings happened, and the three
/// things that change a place.
///
/// Split out because the core file is the session loop and shouldn't have to
/// be read to answer a question about naming.
///
/// THE LINE THIS FILE WALKS: it reads your own sessions, and the gatherings
/// they belong to, to say where YOU were. It never reads anyone else's rows.
/// A place's own totals — evenings, hours together, its stage — come only from
/// `place_summary`, which is an aggregate the database computes.
@MainActor
extension AppState {

    /// Distinct dates YOU docked at a place. `nil` is Somewhere, which counts
    /// exactly the same as anywhere else.
    public func evenings(at place: UUID?) -> Set<String> {
        Set(sessions(at: place).map(\.localDate))
    }

    /// The time of evening you usually do it here — screen 21's one line of
    /// context, and the only thing on it the app hasn't been told outright.
    public func usualTime(at place: UUID?) -> Date? {
        guard let seconds = TimeOfDay.usual(of: sessions(at: place).map(\.startedAt))
        else { return nil }
        return Calendar.current.startOfDay(for: .now).addingTimeInterval(seconds)
    }

    private func sessions(at place: UUID?) -> [Session] {
        recent.filter { session in
            // An unknown gathering is not evidence of Somewhere. Drop it.
            guard session.qualifying, let g = gatherings[session.gatheringId] else { return false }
            return g.placeId == place
        }
    }

    // MARK: - Places

    /// Scanning the card, or picking a place, after the phone is already down.
    ///
    /// Joins the evening already open there — the friend who tapped in first —
    /// or, with nobody there, makes yours the place's. Either way the table
    /// hears you arrive and the place hears it has an evening (screen 4). Your
    /// start time doesn't move, so nothing about what counted changes.
    public func moveHere(_ place: UUID) async {
        guard let s = session, gathering?.placeId != place else { return }
        do {
            let to = try await repo.moveEvening(to: place)
            session = (try? await repo.liveSession()) ?? s
            gathering = try? await repo.gathering(to)
            await learnPlace(of: gathering)
            await refreshMembers()
            Sensation.joined()
            let at = startedAt ?? s.startedAt
            link.connect(gathering: to, me: profile?.id, docked: at,
                         invitation: Invitation(gathering: to, place: place,
                                                name: profile?.displayName,
                                                count: max(1, members.count), at: at))
        } catch {
            banner = t("error.retry")
        }
    }

    /// Screen 21. Mints a place out of the unnamed history: a handle for the
    /// card, a secret for the tag, and every placeless evening of yours moves
    /// onto it.
    ///
    /// The secret is generated here and stored only in the Keychain — the
    /// database keeps its hash, so this is the one moment it exists in the
    /// clear. See `PlaceSecrets`.
    ///
    /// The handle comes from the screen rather than from here, because screen
    /// 21 shows you what the card will say before you commit to the name.
    @discardableResult
    public func nameSomewhere(_ name: String, handle: String) async -> Place? {
        let secret = Handle.newSecret()
        do {
            let id = try await repo.nameSomewhere(handle: handle, secret: secret, name: name)
            PlaceSecrets.save(secret, for: id)
            await reloadPlaces()
            return places.first { $0.id == id }
        } catch {
            banner = t("error.retry")
            return nil
        }
    }

    public func rename(_ place: Place, to name: String) async {
        do {
            try await repo.rename(place: place.id, to: name)
            await reloadPlaces()
        } catch {
            banner = t("error.retry")
        }
    }

    /// The merged-away place is kept, not deleted, so the card already stuck to
    /// someone's fridge keeps resolving (schema review, finding 8).
    public func merge(_ from: Place, into: Place) async {
        do {
            try await repo.mergePlaces(from: from.id, into: into.id)
            await reloadPlaces()
        } catch {
            banner = t("error.retry")
        }
    }

    /// A card for somewhere you've never been makes you one of its people, but
    /// `places` doesn't know yet — and until it does, the name reads Somewhere.
    func learnPlace(of gathering: Gathering?) async {
        guard let id = gathering?.placeId, !places.contains(where: { $0.id == id }) else { return }
        places = (try? await repo.myPlaces()) ?? places
    }

    private func reloadPlaces() async {
        places = (try? await repo.myPlaces()) ?? places
        await loadEvenings()
    }
}
