import Foundation
import ReclaimKit

/// The loop: every way a session starts, everything that happens while it runs,
/// and the way it ends.
///
/// Split from the core file because this is the part with moving parts — a
/// realtime channel, a sensor, a Live Activity — and the store itself should
/// stay readable without them.
@MainActor
extension AppState {

    /// Every way a session begins funnels here: the app, a tag, a control,
    /// Siri, a Shortcut.
    public func setItDown(place: UUID? = nil, source: SessionSource = .app) async {
        let at = Date()
        do {
            let id = try await repo.startOrJoin(place: place, source: source)
            guard let s = try await repo.liveSession(), s.id == id else { return }
            // The moment, as soon as the database says it counts. Render on
            // send and ignore your own echo — otherwise the person who tapped
            // is the last at the table to feel anything, and behind a channel
            // that can take a minute to refuse, the last by a long way.
            Sensation.docked()
            await adopt(session: s, at: at, announcing: true)
        } catch {
            banner = t("error.retry")
        }
    }

    public func end() async {
        guard let s = session else { return }
        let people = max(1, members.count)
        let place = placeName
        let placeId = gathering?.placeId
        let estimate = Int(Date().timeIntervalSince(startedAt ?? s.startedAt) / 60)
        if let me = profile?.id { await transport.send(.released(profile: me), from: me) }
        // What the database credited is what counted — capped, if it came to
        // that. The phone's own clock is only the fallback.
        let credited = try? await repo.endSession(s.id)
        Sensation.ended()
        // Set in the same turn as the teardown, so Home never flashes between.
        let minutes = max(0, credited ?? estimate)
        justEnded = Ended(startedAt: startedAt ?? s.startedAt, endedAt: .now, minutes: minutes,
                          people: people, place: place, placeId: placeId,
                          landing: EveningLanding(total: eveningTotal, known: evenings,
                                                  localDate: s.localDate, minutes: minutes))
        await teardown()
        self.rhythm = (try? await repo.myRhythm()) ?? rhythm
        await loadEvenings()
        await rescheduleNudges()
    }

    /// Everything on this phone first, then what the database knows, then the
    /// channel — queued, never awaited. `announcing` is for a session this
    /// phone just started, as opposed to one found running at launch.
    func adopt(session s: Session, at: Date? = nil, announcing: Bool = false) async {
        session = s
        startedAt = at ?? s.startedAt
        faceDown.start { [weak self] down in
            guard let self else { return }
            Task { @MainActor in await self.setFaceDown(down) }
        }
        // Never buzz during a session. A nudge mid-evening is the app becoming
        // the thing it replaces.
        Notifications.silenceForSession()
        // What the Control Centre toggle draws itself from, since a control
        // can't ask the database and has to answer instantly.
        SessionFlag.isLive = true
        // Nothing invites you to a table you are already sitting at.
        invitePump?.cancel(); invitePump = nil
        watching = []
        stopListeningNearby()
        offers.forget()
        listen()

        gathering = try? await repo.gathering(s.gatheringId)
        await learnPlace(of: gathering)
        members = (try? await repo.members(of: s.gatheringId)) ?? []
        await LiveActivityController.start(
            gatheringId: s.gatheringId,
            startedAt: startedAt ?? s.startedAt,
            memberCount: max(1, members.count),
            placeName: placeName)

        // Your own name, from your own row, to the place — the only way anyone
        // learns it before they join (screen 4).
        let invitation = gathering?.placeId.map {
            Invitation(gathering: s.gatheringId, place: $0, name: profile?.displayName,
                       count: max(1, members.count), at: startedAt ?? s.startedAt)
        }
        link.connect(gathering: s.gatheringId, me: profile?.id,
                     docked: announcing ? startedAt : nil,
                     invitation: announcing ? invitation : nil)
        await beFindable()
    }

    /// What `load()` does once it knows what the database thinks is running.
    func reconcile(_ r: Reconciliation) async {
        switch r {
        case .keep:          break
        case .refresh:       await refreshMembers()
        case .adopt(let s):  await adopt(session: s)
        case .end:
            await teardown()
            await rescheduleNudges()
        case .idle:
            // Nothing is running, so nothing may be SHOWING. An evening ended
            // from the lock screen, from Siri or at the cap leaves this phone
            // with an activity and a flag nobody cleared — and the next launch
            // is where that gets noticed. The guard is for the tap that starts
            // an evening in the same breath as a refresh.
            if session == nil {
                await LiveActivityController.end()
                SessionFlag.isLive = false
            }
            watchPlaces()
        }
    }

    private func teardown() async {
        pump?.cancel(); pump = nil
        faceDown.stop()
        beacon.stop()
        link.disconnect()
        await LiveActivityController.end()
        session = nil; gathering = nil; members = []; startedAt = nil
        iAmFaceDown = false
        SessionFlag.isLive = false
        watchPlaces()
    }

    // MARK: - Invitations

    /// Listening at your own places while nothing is running. This is the only
    /// thing the app does in the background, and all it can ever hear is that
    /// somebody arrived somewhere you both know. Queued behind anything the
    /// link is still doing, so a slow subscribe holds up nothing else.
    func watchPlaces() {
        // The radio doesn't need a place to be worth listening to — a table
        // you've never been to is exactly what it's for.
        listenNearby()
        let ids = places.map(\.id)
        guard !ids.isEmpty, ids != watching else { return }
        watching = ids
        link.watch(places: ids)
        invitePump?.cancel()
        let stream = transport.invitations()
        invitePump = Task { [weak self] in
            for await invitation in stream {
                guard let self else { return }
                await self.offer(invitation)
            }
        }
    }

    func offer(_ invitation: Invitation) async {
        // Not while you're already in one, and not for one that has been sitting
        // there since before you picked the phone up — that last part only for
        // the channel. A table found by radio is one you are standing next to,
        // and a dinner that began two hours ago is still worth joining.
        guard !isLive else { return }
        guard invitation.isNearby || invitation.at.timeIntervalSinceNow > -60 * 60 else { return }
        self.invitation = invitation
        Sensation.joined()
    }

    /// Screen 4's one button. Joining goes through the same call as everything
    /// else, so the open gathering at that place is what you land in — the
    /// database settles the race, not the phone.
    public func join(_ invitation: Invitation) async {
        self.invitation = nil
        if let key = invitation.key {
            await joinNearby(key)
        } else if let place = invitation.place {
            await setItDown(place: place, source: .app)
        }
    }

    private func setFaceDown(_ down: Bool) async {
        iAmFaceDown = down
        guard let me = profile?.id else { return }
        await transport.send(.faceDown(profile: me, down: down), from: me)
    }

    private func listen() {
        pump?.cancel()
        let stream = transport.events()
        pump = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: CeremonyEvent) async {
        switch event {
        case .docked:
            // Someone else joined. The count only goes up.
            Sensation.joined()
            await refreshMembers()
        case .faceDown:
            await refreshMembers()
        case .released:
            await refreshMembers()
        }
    }

    public func refreshMembers() async {
        guard let id = session?.gatheringId else { return }
        members = (try? await repo.members(of: id)) ?? members
        await LiveActivityController.update(
            startedAt: startedAt ?? .now,
            memberCount: max(1, members.count),
            placeName: placeName)
    }
}
