import Foundation
import ReclaimKit

/// The few seconds between a phone coming out of the box and its evening
/// ending. They used to pass in silence — fifteen of them — and a person
/// holding the phone had no way to know when it would end, or that putting
/// it back would carry on. Now they count down, on the lock screen and in the
/// app, and a phone back in a slot before zero picks up where it was.
@MainActor
extension AppState {

    /// Out — by the box's word, or by the app finding itself in a hand that
    /// isn't charging. Ends the evening at zero unless the phone is back.
    func leaving() async {
        guard leavingUntil == nil else { return }
        let until = Date().addingTimeInterval(Box.outGrace)
        leavingUntil = until
        await showLeaving(until)
        try? await Task.sleep(for: .seconds(Box.outGrace))
        // Back in a slot already, and the countdown cleared.
        guard leavingUntil == until else { return }
        leavingUntil = nil
        if Box.hasLeft(docked: DockSlot.current != nil, charging: ChargingWatch.shared.isCharging) {
            await leftBox()
        } else {
            await showLeaving(nil)
        }
    }

    /// A slot filled while counting down: if this phone is charging again,
    /// it's back, and the evening carries on.
    func maybeBack() async {
        guard leavingUntil != nil, await ChargingWatch.shared.charging(within: 3) else { return }
        leavingUntil = nil
        await showLeaving(nil)
    }

    private func showLeaving(_ until: Date?) async {
        guard isLive else { return }
        await LiveActivityController.update(startedAt: startedAt ?? .now, memberCount: max(1, memberCount),
                                            placeName: placeName, endingAt: until)
    }
}
