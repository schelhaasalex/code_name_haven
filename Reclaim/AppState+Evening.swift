import Foundation
import ReclaimKit

/// The evening: how it starts, what the phone keeps while it runs, and how it
/// ends. Only the box starts one (`AppState+Box`, `AppState+Dock`) and only
/// the box ends one — or the server, at its cap.
@MainActor
extension AppState {

    /// The phone went into the box. Joins the evening already open there, or
    /// opens it.
    func setItDown(place: UUID, source: SessionSource = .tag) async {
        let at = Date()
        do {
            let id = try await repo.startOrJoin(place: place, source: source)
            guard let s = try await repo.liveSession(), s.id == id else { return }
            await adopt(session: s, at: at)
        } catch {
            banner = t("error.retry")
        }
    }

    /// The phone came out of the box and didn't go back (`leftBox`).
    func end() async {
        guard let s = session else { return }
        let people = max(1, members.count)
        let place = placeName
        let placeId = gathering?.placeId
        let estimate = Int(Date().timeIntervalSince(startedAt ?? s.startedAt) / 60)
        // What the database credited is what counted — capped, if it came to
        // that. The phone's own clock is only the fallback.
        let credited = try? await repo.endSession(s.id)
        // Set in the same turn as the teardown, so Home never flashes between.
        let minutes = max(0, credited ?? estimate)
        justEnded = Ended(startedAt: startedAt ?? s.startedAt, endedAt: .now, minutes: minutes,
                          people: people, place: place, placeId: placeId,
                          landing: EveningLanding(total: eveningTotal, known: evenings,
                                                  localDate: s.localDate, minutes: minutes))
        await teardown()
        await loadEvenings()
    }

    /// Everything on this phone first, then what the database knows.
    func adopt(session s: Session, at: Date? = nil) async {
        session = s
        startedAt = at ?? s.startedAt
        gathering = try? await repo.gathering(s.gatheringId)
        if let id = gathering?.placeId, !places.contains(where: { $0.id == id }) {
            places = (try? await repo.myPlaces()) ?? places
        }
        members = (try? await repo.members(of: s.gatheringId)) ?? []
        await LiveActivityController.start(
            gatheringId: s.gatheringId,
            startedAt: startedAt ?? s.startedAt,
            memberCount: max(1, members.count),
            placeName: placeName)
    }

    /// What `load()` does once it knows what the database thinks is running.
    func reconcile(_ r: Reconciliation) async {
        switch r {
        case .keep:          break
        case .refresh:       await refreshMembers()
        case .adopt(let s):  await adopt(session: s)
        case .end:           await teardown()
        case .idle:
            // Nothing is running, so nothing may be SHOWING: an evening the
            // server closed at its cap leaves this phone with an activity
            // nobody cleared.
            if session == nil { await LiveActivityController.end() }
        }
    }

    func teardown() async {
        await LiveActivityController.end()
        session = nil; gathering = nil; members = []; startedAt = nil
        // However it ended, the box goes dark for this phone — never waited on.
        Task { await DockSlot.undock() }
    }

    /// Who's in the box with you. The count only goes up (rule 3).
    func refreshMembers() async {
        guard let id = session?.gatheringId else { return }
        members = (try? await repo.members(of: id)) ?? members
        await LiveActivityController.update(
            startedAt: startedAt ?? .now,
            memberCount: max(1, members.count),
            placeName: placeName)
    }
}
