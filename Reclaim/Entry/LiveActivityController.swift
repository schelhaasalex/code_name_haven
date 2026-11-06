import Foundation
import ActivityKit
import ReclaimKit

/// Screens 7 and 19 — the pair that earn the native rewrite. Start without
/// unlocking, end without unlocking, app never opened in between.
@MainActor
enum LiveActivityController {

    private static var current: Activity<ReclaimActivityAttributes>?

    /// Whether this phone is showing one at all — the one a push started
    /// included, which `start` then adopts by its gathering.
    static var showing: Bool { !Activity<ReclaimActivityAttributes>.activities.isEmpty }

    /// Where this build's pushes go. Run from Xcode: Apple's sandbox. From
    /// TestFlight or the App Store: production. A token sent to the other is
    /// refused.
    static var pushEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// This device's push-to-start token, each time iOS hands one out — it can
    /// change, and the server has to have the current one. iOS 17.2 and later;
    /// before that, an evening started in the background shows its Live
    /// Activity the next time the app is opened.
    static func watchPushToStartTokens(_ save: @escaping @MainActor (String) async -> Void) {
        guard #available(iOS 17.2, *) else { return }
        Task { @MainActor in
            for await token in Activity<ReclaimActivityAttributes>.pushToStartTokenUpdates {
                await save(RemoteActivity.hex(token))
            }
        }
    }

    /// Each running activity's own token, as iOS hands it out, for the server
    /// to push the ring's steps to (`charge-live-activities`). Activities a
    /// push started arrive through `activityUpdates` — iOS wakes the app for
    /// them — and the ones the app starts itself are watched from `start`.
    static func watchActivityTokens(
        _ save: @escaping @MainActor (_ gathering: UUID, _ token: String, _ state: String) async -> Void
    ) {
        saveToken = save
        for activity in Activity<ReclaimActivityAttributes>.activities { watch(activity) }
        Task { @MainActor in
            for await activity in Activity<ReclaimActivityAttributes>.activityUpdates { watch(activity) }
        }
    }

    private static var saveToken: (@MainActor (UUID, String, String) async -> Void)?
    private static var watched: Set<String> = []

    private static func watch(_ activity: Activity<ReclaimActivityAttributes>) {
        guard watched.insert(activity.id).inserted else { return }
        Task { @MainActor in
            for await token in activity.pushTokenUpdates {
                guard let state = try? RemoteActivity.stateJSON(activity.content.state) else { continue }
                await saveToken?(activity.attributes.gatheringId, RemoteActivity.hex(token), state)
            }
        }
    }

    /// Reuses the activity already showing for this gathering, if the app was
    /// relaunched under it, rather than ending it and starting an identical one.
    static func start(gatheringId: UUID, startedAt: Date, memberCount: Int, placeName: String?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = ReclaimActivityAttributes.ContentState(
            startedAt: startedAt, memberCount: memberCount, placeName: placeName,
            stage: EveningCharge.stage(since: startedAt))
        if let running = Activity<ReclaimActivityAttributes>.activities
            .first(where: { $0.attributes.gatheringId == gatheringId }) {
            current = running
            await running.update(.init(state: state, staleDate: nil))
            return
        }
        await end()
        // `.token`, so the server can step the ring while the phone sleeps.
        // Without a push token it still shows; it just doesn't charge.
        current = (try? Activity.request(
            attributes: ReclaimActivityAttributes(gatheringId: gatheringId),
            content: .init(state: state, staleDate: nil), pushType: .token))
            ?? (try? Activity.request(
                attributes: ReclaimActivityAttributes(gatheringId: gatheringId),
                content: .init(state: state, staleDate: nil)))
        if let current { watch(current) }
    }

    static func update(startedAt: Date, memberCount: Int, placeName: String?) async {
        guard let current = current ?? Activity<ReclaimActivityAttributes>.activities.first
        else { return }
        Self.current = current
        await current.update(.init(
            state: .init(startedAt: startedAt, memberCount: memberCount, placeName: placeName,
                         stage: EveningCharge.stage(since: startedAt)),
            staleDate: nil))
    }

    /// Every activity, not just the one this launch remembers. The End button
    /// relaunches the app in the background with no memory of the activity it
    /// is ending — ending only `current` left it on the lock screen, counting
    /// up for an evening that was over. Shared with the intent, which does
    /// this for itself rather than waiting for the app to get here.
    static func end() async {
        await ReclaimActivity.endAll()
        current = nil
    }
}
