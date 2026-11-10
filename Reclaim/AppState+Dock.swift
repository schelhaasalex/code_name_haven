import Foundation
import UIKit
import ReclaimKit

/// The box's code, read with the phone in a hand — off its card, or off the
/// screen of a phone already in the box (`boxCode(for:)`). It pairs, and
/// starts nothing: only the box's radio starts an evening (`AppState+Box`).
/// Read first, it makes the box this phone's.
@MainActor
extension AppState {

    /// A box's code was read. False when the box couldn't be found, which
    /// only the scanner asks.
    @discardableResult
    public func dock(_ link: Dock.Link) async -> Bool {
        if phase != .ready { await load() }
        codeRanOut = false
        guard let place = await boxPlace(secret: link.secret) else {
            banner = t(codeRanOut ? "scan.ranout.body" : "error.retry")
            if !codeRanOut { note(.dockFailed) }
            return false
        }
        meet(place)
        pairBox(place: place, box: link.box)
        places = (try? await repo.myPlaces()) ?? places
        await nameIfUnnamed(place)
        boxSummaries[place] = (try? await repo.summary(of: place)) ?? boxSummaries[place]
        return true
    }

    /// Catching up with the box on every return to the foreground.
    ///
    /// A phone that left the box without the box's word reaching it — out of
    /// range, or the wake missed. Every return to the foreground checks, and
    /// a phone in the hand that isn't charging has left: its evening counts
    /// down to its end.
    /// The grace after docking is for the pad, which starts charging a moment
    /// after the phone lands.
    func checkDock() async {
        // An evening the box started while the app was asleep has no Live
        // Activity — iOS won't let a background wake start one. The first look
        // at the app is where it appears; for one already showing, this only
        // refreshes it.
        if let s = session, isLive {
            await LiveActivityController.start(gatheringId: s.gatheringId,
                                               startedAt: startedAt ?? s.startedAt,
                                               memberCount: max(1, memberCount),
                                               placeName: placeName)
        }
        guard DockSlot.current != nil else { return }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let charging = device.batteryState == .charging || device.batteryState == .full
        // The same countdown as the box's, not an ending on the spot: opening
        // the app is often the first thing a lifted phone does.
        if DockSlot.hasLeft(since: DockSlot.since, charging: charging) {
            Task { await leaving() }
        }
    }

    /// Found, or made by this phone, being the first to read the box. A handle
    /// someone else drew comes back nil; three draws from 256 is plenty.
    private func boxPlace(secret: String) async -> UUID? {
        for _ in 0..<3 {
            do {
                if let id = try await repo.dockPlace(secret: secret, handle: Handle.generate()) {
                    return id
                }
            } catch DockError.codeRanOut {
                codeRanOut = true
                return nil
            } catch {
                return nil
            }
        }
        return nil
    }
}
