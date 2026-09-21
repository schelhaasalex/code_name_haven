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
            await adopt(session: s, at: at)
            // Render on send, ignore your own echo — otherwise the person who
            // tapped is the last at the table to feel anything.
            Sensation.docked()
            if let me = profile?.id {
                await transport.send(.docked(at: at), from: me)
            }
            // And tell the place, so the others get screen 4. Your own name,
            // from your own row — it is the only way anyone learns it before
            // they join.
            if let placeId = gathering?.placeId {
                await transport.announce(
                    Invitation(gathering: s.gatheringId, place: placeId,
                               name: profile?.displayName,
                               count: max(1, members.count), at: at))
            }
        } catch {
            banner = t("error.retry")
        }
    }

    public func end() async {
        guard let s = session else { return }
        if let me = profile?.id { await transport.send(.released(profile: me), from: me) }
        _ = try? await repo.endSession(s.id)
        Sensation.ended()
        await teardown()
        self.rhythm = (try? await repo.myRhythm()) ?? rhythm
        await loadEvenings()
        await Notifications.reschedule(for: profile)
    }

    private func adopt(session s: Session, at: Date? = nil) async {
        session = s
        startedAt = at ?? s.startedAt
        gathering = try? await repo.gathering(s.gatheringId)
        members = (try? await repo.members(of: s.gatheringId)) ?? []
        try? await transport.join(gathering: s.gatheringId)
        listen()
        faceDown.start { [weak self] down in
            guard let self else { return }
            Task { @MainActor in await self.setFaceDown(down) }
        }
        // Never buzz during a session. A nudge mid-evening is the app becoming
        // the thing it replaces.
        Notifications.silenceForSession()
        // Nothing invites you to a table you are already sitting at.
        await stopWatchingPlaces()
        // What the Control Centre toggle draws itself from, since a control
        // can't ask the database and has to answer instantly.
        SessionFlag.isLive = true
        await LiveActivityController.start(
            gatheringId: s.gatheringId,
            startedAt: startedAt ?? s.startedAt,
            memberCount: max(1, members.count),
            placeName: placeName)
    }

    private func teardown() async {
        pump?.cancel(); pump = nil
        faceDown.stop()
        await transport.leave()
        await LiveActivityController.end()
        session = nil; gathering = nil; members = []; startedAt = nil
        iAmFaceDown = false
        SessionFlag.isLive = false
        await watchPlaces()
    }

    // MARK: - Invitations

    /// Listening at your own places while nothing is running. This is the only
    /// thing the app does in the background, and all it can ever hear is that
    /// somebody arrived somewhere you both know.
    func watchPlaces() async {
        let ids = places.map(\.id)
        guard !ids.isEmpty else { return }
        await transport.watch(places: ids)
        invitePump?.cancel()
        let stream = transport.invitations()
        invitePump = Task { [weak self] in
            for await invitation in stream {
                guard let self else { return }
                await self.offer(invitation)
            }
        }
    }

    func stopWatchingPlaces() async {
        invitePump?.cancel(); invitePump = nil
        await transport.stopWatching()
    }

    private func offer(_ invitation: Invitation) async {
        // Not while you're already in one, and not for one that has been sitting
        // there since before you picked the phone up.
        guard !isLive, invitation.at.timeIntervalSinceNow > -60 * 60 else { return }
        self.invitation = invitation
        Sensation.joined()
    }

    /// Screen 4's one button. Joining goes through the same call as everything
    /// else, so the open gathering at that place is what you land in — the
    /// database settles the race, not the phone.
    public func join(_ invitation: Invitation) async {
        self.invitation = nil
        await setItDown(place: invitation.place, source: .app)
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
