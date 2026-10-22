import Foundation
import Network

/// The lights on the outside of the box.
///
/// Every call is fire-and-forget, and none of them can fail out loud: the
/// controller unplugged, a different Wi-Fi, Local Network declined — the box
/// stays dark and the evening counts exactly the same (rule 7). Nothing here
/// returns anything to wait on, so nothing can be made to wait on it.
///
/// The controller is found over Bonjour the first time and remembered for as
/// long as the process lives. A send that fails forgets it and looks once more,
/// because a controller that restarted may have come back somewhere else.
///
/// The first browse is also what asks for Local Network access — the moment a
/// phone is in a box, which is the only moment the question makes sense.
public final class DockLight: @unchecked Sendable {

    public static let shared = DockLight()

    /// Everything below is touched only on this queue.
    private let queue = DispatchQueue(label: "reclaim.dock-light")
    private var controller: NWEndpoint?
    private var browser: NWBrowser?
    private var waiting: [(NWEndpoint?) -> Void] = []
    /// Which browse a timeout belongs to, so one left over from an earlier
    /// look can't call off the one running now.
    private var looking = 0

    /// Long enough for a controller on the same Wi-Fi to answer; short enough
    /// that a box with no lights doesn't keep a radio busy.
    private let patience: TimeInterval = 4

    public func set(slot: Int, on: Bool) {
        set(slot: slot, on: on, then: {})
    }

    /// The same, for a process that may be suspended the moment it returns —
    /// an intent run by a Shortcut. Finishes when the light has been told, or
    /// when it's clear it can't be; never throws, and never takes long.
    public func settle(slot: Int, on: Bool) async {
        await withCheckedContinuation { done in
            set(slot: slot, on: on) { done.resume() }
        }
    }

    private func set(slot: Int, on: Bool, then done: @escaping () -> Void) {
        guard Dock.slots.contains(slot) else { return done() }
        let request = WLED.request(body: WLED.state(segment: Dock.segment(forSlot: slot), on: on))
        queue.async { self.send(request, retrying: true, then: done) }
    }

    private func send(_ request: Data, retrying: Bool, then done: @escaping () -> Void) {
        find { endpoint in
            guard let endpoint else { return done() }
            self.post(request, to: endpoint) { ok in
                guard !ok, retrying else { return done() }
                self.controller = nil
                self.send(request, retrying: false, then: done)
            }
        }
    }

    // MARK: - Finding it

    private func find(_ found: @escaping (NWEndpoint?) -> Void) {
        if let controller { return found(controller) }
        waiting.append(found)
        guard browser == nil else { return }

        let browser = NWBrowser(for: .bonjour(type: WLED.service, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            // The first one. A house with more than one WLED is a prototype
            // problem this doesn't solve yet; see docs/DOCK.md.
            guard let self, let first = results.first?.endpoint else { return }
            self.finish(first)
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.finish(nil) }
        }
        self.browser = browser
        looking += 1
        let look = looking
        browser.start(queue: queue)
        queue.asyncAfter(deadline: .now() + patience) { [weak self] in
            guard let self, self.looking == look else { return }
            self.finish(nil)
        }
    }

    private func finish(_ endpoint: NWEndpoint?) {
        guard browser != nil else { return }
        browser?.cancel()
        browser = nil
        controller = endpoint
        let waiting = waiting
        self.waiting = []
        waiting.forEach { $0(endpoint) }
    }

    // MARK: - Telling it

    private func post(_ request: Data, to endpoint: NWEndpoint, then done: @escaping (Bool) -> Void) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        var answered = false
        let answer: (Bool) -> Void = { ok in
            guard !answered else { return }
            answered = true
            connection.cancel()
            done(ok)
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: request, completion: .contentProcessed { error in
                    guard error == nil else { return answer(false) }
                    // Wait for the reply's first bytes, so the connection
                    // isn't torn down before the controller has read it all.
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { _, _, _, error in
                        answer(error == nil)
                    }
                })
            case .failed, .waiting:
                answer(false)
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + patience) { answer(false) }
    }
}
