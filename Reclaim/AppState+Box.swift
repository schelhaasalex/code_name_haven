import Foundation
import UIKit
import ReclaimKit

/// The box that notices: a phone set into a slot starts its evening with
/// nobody touching anything.
///
/// The box tells every phone connected to it that a slot filled; each phone
/// asks itself whether that was it (`Box.isThisPhone`), and the one that just
/// started charging, with the box right beside it, starts the evening at the
/// box's place. Taking it out ends it, `Box.outGrace` later, unless it's back
/// by then (rule 4).
///
/// All of this happens with the app woken in the background for a few
/// seconds. The slot's tag still works whatever happens here.
@MainActor
extension AppState {

    /// At launch, including the background launches the box causes.
    func watchBox() {
        _ = ChargingWatch.shared
        LiveActivityController.watchPushToStartTokens { [weak self] token in
            try? await self?.repo.saveActivityToken(token, environment: LiveActivityController.pushEnvironment)
        }
        LiveActivityController.watchActivityTokens { [weak self] gathering, token, state in
            try? await self?.repo.saveLiveActivity(token: token, gatheringId: gathering,
                                                   environment: LiveActivityController.pushEnvironment, state: state)
        }
        boxLink.resume { [weak self] now, before, rssi in
            guard let self else { return }
            Task { await self.boxChanged(now, before: before, rssi: rssi) }
        }
    }

    /// The first read of a box's tag or code teaches this phone which box is
    /// its own — the place at once, and the radio a few seconds later: the
    /// dock it's closest to, right then. Asks about Bluetooth, the first time
    /// — at the box, where the question makes sense.
    ///
    /// Every read listens again, even for the box this phone already knows:
    /// its radio can change under the same tags and code — a new board, a
    /// reflash — and a phone that kept the old one would wait for it forever.
    /// Until a radio is heard, the one it knew stays.
    func pairBox(place: UUID) {
        let known = BoxPairing.current
        BoxPairing.current = BoxPairing(place: place,
                                        peripheral: known?.place == place ? known?.peripheral : nil)
        pairing = .listening
        boxLink.pair { [weak self] peripheral in
            guard BoxPairing.current?.place == place else { return }
            if let peripheral { BoxPairing.current = BoxPairing(place: place, peripheral: peripheral) }
            self?.pairing = peripheral == nil ? .notHeard : .paired
        }
    }

    private func boxChanged(_ now: Box.Slots, before: Box.Slots, rssi: Int?) async {
        // The few seconds iOS gives a Bluetooth wake, stretched to cover a
        // database round trip.
        let task = UIApplication.shared.beginBackgroundTask()
        defer { UIApplication.shared.endBackgroundTask(task) }

        let filled = now.filled(since: before)
        let emptied = now.emptied(since: before)
        if !filled.isEmpty, DockSlot.current == nil, !isLive {
            await maybeIn(filled, rssi: rssi)
        } else if !emptied.isEmpty, DockSlot.current != nil {
            await maybeOut()
        }
    }

    private func maybeIn(_ filled: Set<Int>, rssi: Int?) async {
        let at = Date()
        let charging = await ChargingWatch.shared.charging(within: 6)
        let fresh = Box.justStarted(chargingSince: ChargingWatch.shared.since, at: at)
        guard Box.isThisPhone(charging: charging, wasCharging: !fresh, rssi: rssi),
              let place = BoxPairing.current?.place
        else { return }

        // Two slots filling at once leaves which one was this phone a guess;
        // the box lights its own slots, so the guess only matters to this phone.
        DockSlot.docked(in: filled.min() ?? 1)
        // Woken in the background, the app may not have looked at anything yet.
        if phase != .ready { await load() }
        guard phase == .ready, !isLive else { return }
        await setItDown(place: place, source: .tag)
        await showOnLockScreen()
    }

    /// iOS refuses a Live Activity to an app in the background, which is where
    /// the box starts every evening. The server can start one with a push
    /// (`start-live-activity`), so it's there when the screen is next woken.
    /// Never waited on for anything that matters: the evening already counts.
    private func showOnLockScreen() async {
        guard isLive, !LiveActivityController.showing, let s = session else { return }
        let state = ReclaimActivityAttributes.ContentState(
            startedAt: startedAt ?? s.startedAt, memberCount: max(1, members.count), placeName: placeName,
            stage: EveningCharge.stage(since: startedAt ?? s.startedAt))
        let place = placeName ?? t("box.unnamed")
        guard let body = try? RemoteActivity.startBody(
            gatheringId: s.gatheringId, state: state,
            title: t("starttap.banner.title", "place", place), body: t("starttap.banner.body"))
        else { return }
        try? await repo.startActivityRemotely(body: body)
    }

    /// Somebody's phone came out. If it was this one and it isn't back once
    /// the grace is up, its evening is over.
    private func maybeOut() async {
        try? await Task.sleep(for: .seconds(Box.outGrace))
        if Box.hasLeft(docked: DockSlot.current != nil, charging: ChargingWatch.shared.isCharging) {
            await leftBox()
        }
    }

    /// Out of the box and not back: the evening ends, and the slot goes dark.
    /// The Live Activity goes with it, from here, and the server's next
    /// minute ends it on any phone this one couldn't reach.
    func leftBox() async {
        if phase != .ready { await load() }
        if isLive { await end() }
        await DockSlot.undock()
    }
}
