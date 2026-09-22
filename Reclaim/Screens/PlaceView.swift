import SwiftUI
import ReclaimKit

/// Screen 9. A place, and what it has become.
///
/// Every number here comes from `place_summary`, which is an aggregate over
/// everyone who has ever docked here — the one honest way to say "sixty-eight
/// hours together" without the client ever reading another person's rows.
///
/// What it deliberately does NOT show is a calendar of which evenings happened
/// here. The app knows your own dates and the place's totals; it does not know
/// your dates AT this place without an RPC that doesn't exist yet. Drawing that
/// grid would mean guessing, and the knowledge test says don't.
struct PlaceView: View {
    @Environment(AppState.self) private var state
    let place: Place

    @State private var summary: PlaceSummary?
    @State private var renaming = false
    @State private var inviting = false

    private var isLive: Bool { state.gathering?.placeId == place.id && !others.isEmpty }

    /// The people in the gathering you are in, minus you. Empty when you are
    /// the only one here, and the banner goes away rather than saying "you are
    /// here right now" to your face.
    private var others: [String] {
        state.members
            .filter { $0.profileId != state.profile?.id && $0.stillLive }
            .compactMap(\.displayName)
    }
    private var canRename: Bool { place.createdBy == state.profile?.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                heading
                if isLive { live }
                stats
                stage
                lately
                card
                if canRename { rename }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { summary = try? await state.repo.summary(of: place.id) }
        .sheet(isPresented: $renaming) { NamingView(place: place) }
        .sheet(isPresented: $inviting) { InviteSheet(place: place) }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: Handle.pretty(place.handle))
            Text(place.name ?? t("places.somewhere.title"))
                .font(Type.title).foregroundStyle(Palette.ink)
        }
    }

    /// Only ever the people already in the gathering with you — the same list
    /// screen 6 draws, and the only thing the app learns about anyone else.
    private var live: some View {
        NightCard {
            HStack(spacing: 9) {
                Circle().fill(Palette.ember).frame(width: 8, height: 8)
                Text(t("place.live", "names", Say.names(others)))
                    .font(Type.body(15)).foregroundStyle(Palette.cream)
            }
        }
    }

    private var stats: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 18) {
                StatRow(title: t("place.stat.evenings"),
                        value: "\(summary?.evenings ?? 0)")
                StatRow(title: t("place.stat.hours"),
                        value: Say.duration(minutes: summary?.wallClockMinutes ?? 0))
            }
        }
    }

    private var stage: some View {
        LabelledSection(label: t("place.stage.label")) {
            Text(stageName).font(Type.subhead).foregroundStyle(Palette.clay)
            if let month = Say.month(from: summary?.since) {
                Text(t("place.stage.since", "month", month))
                    .font(Type.body(14)).foregroundStyle(Palette.ink2)
            }
            Text(t("place.stage.next"))
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
        }
    }

    /// The database names the stage; the app only looks up how to say it, so
    /// the thresholds live in one place and screen 9 can't drift from them.
    private var stageName: String {
        switch summary?.stage {
        case "a regular table": t("place.stage.regular")
        case "a reclaim house": t("place.stage.house")
        case "a landmark":      t("place.stage.landmark")
        default:                t("place.stage.new")
        }
    }

    /// YOUR evenings here, four weeks of them. Said in those words, because
    /// the numbers above are everyone's and these are not — the app knows your
    /// own dates and would be guessing at anyone else's.
    private var lately: some View {
        LabelledSection(label: t("place.lately")) {
            DayGrid(days: EveningCalendar.grid(evenings: state.evenings(at: place.id), weeks: 4))
            Text(t("place.lately.note"))
                .font(Type.note).foregroundStyle(Palette.muted)
        }
    }

    private var card: some View {
        LabelledSection(label: t("place.card.label")) {
            Text(t("place.card.body"))
                .font(Type.body(14)).foregroundStyle(Palette.ink2).lineSpacing(3)
            NavigationLink(value: Route.card(place.id)) {
                Text(t("place.card.print"))
                    .font(Type.body(15, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(Palette.ink)
                    .overlay { Capsule().stroke(Palette.hairline, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            // The other way in: for someone who isn't at the table to scan it.
            TextAction(title: t("place.invite"), icon: "person.badge.plus") { inviting = true }
        }
    }

    private var rename: some View {
        TextAction(title: t("place.rename"), icon: "pencil") { renaming = true }
    }
}

#Preview {
    NavigationStack {
        PlaceView(place: Place(id: UUID(), name: "The Kitchen Table", handle: "amber-otter"))
    }
    .environment(AppState(repo: PreviewRepository()))
}
