import SwiftUI
import ReclaimKit

/// Screen 2 — Home: your evenings as a sky, with today's star among them
/// and this week's drawn darkest; the box you were last at above it. With no
/// box yet, the one thing there is to do: meet it.
///
/// The sky is the point, so it is the largest thing here. Today's star waits
/// as an outline until today has counted, and every evening that counts
/// stays. The week is in the sky, not a row of dots beside it: a row has to
/// draw the days that didn't count, and this screen only draws the ones that
/// did. What each box has kept is the long view, on the box's own page in
/// Settings — not the reason to set the phone down tonight.
///
/// NO BUTTON TO START. The box is the only switch; Home is what it leaves
/// behind. And no tab bar: a tab bar advertises that there's something to
/// browse, which is the one thing this app shouldn't say.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var scanning = false
    @State private var aboutStar = false
    /// VoiceOver's way to what it's for, where the headline's tap is folded
    /// into the one combined element.
    @State private var reasonPage = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 16)
                if state.boxPlace == nil {
                    pair
                } else {
                    today
                }
                Spacer(minLength: 16)
            }
            .ground()
            .navigationDestination(for: Settings.self) { _ in SettingsView() }
            // From the headline here, and from Settings, which this stack holds.
            .navigationDestination(for: ReasonView.Route.self) { _ in ReasonView() }
            .fullScreenCover(isPresented: $scanning) { ScanView() }
            .sheet(isPresented: $aboutStar) { StarSheet(counted: countedToday) }
            .navigationDestination(isPresented: $reasonPage) { ReasonView() }
        }
    }

    /// The one destination, so the link has something to say it is.
    struct Settings: Hashable {}

    /// The mark and the box, as the evening screen has them: it's where you
    /// are, not what this screen is about. Before there is one, the app's
    /// own name.
    private var header: some View {
        HStack {
            Eyebrow(text: state.boxPlace == nil ? t("app.name") : placeName)
            Spacer()
            NavigationLink(value: Settings()) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 19)).foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(t("home.a11y.settings"))
        }
    }

    private var pair: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("pair.headline")).font(Type.hero).foregroundStyle(Palette.ink)
            Text(t("pair.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
            PrimaryButton(title: t("pair.scan")) { scanning = true }
                .padding(.top, 12)
        }
    }

    // MARK: Today

    /// Every evening you've had, and today's. Nothing until the database has
    /// said how many — a guessed sky would be a lie.
    @ViewBuilder private var today: some View {
        if let total = state.eveningTotal {
            let layout = EveningMarkLayout.today(total: total.count, counted: countedToday)
            VStack(spacing: 28) {
                EveningMark(layout: layout, size: 290, recent: thisWeek - (countedToday ? 1 : 0),
                            pulse: true, onTonight: { aboutStar = true }, seed: state.skySeed)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: layout)
                VStack(spacing: 8) {
                    // Keeps time: "afternoon" becomes "evening" at five
                    // without the app being opened again.
                    TimelineView(.everyMinute) { context in
                        Text(Say.partOfDay(context.date)).eyebrow(Palette.clay)
                    }
                    // What the time is for, not an order: the box is named
                    // above, and the line under says how it starts. Tapping
                    // it opens what it's for.
                    NavigationLink(value: ReasonView.Route()) {
                        Text(headline).font(Type.display(26)).foregroundStyle(Palette.ink)
                    }
                    .buttonStyle(.plain)
                    if !countedToday {
                        Text(t("home.starts")).font(Type.body(15)).foregroundStyle(Palette.ink2)
                    }
                    // Nothing at all before the first day: the headline has
                    // already said the one thing there is to do.
                    let days = Say.days(total: total.count, thisWeek: thisWeek,
                                        month: Say.month(from: total.first) ?? "")
                    if !days.isEmpty {
                        Text(days).font(Type.body(14)).foregroundStyle(Palette.muted)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: t("home.a11y.star")) { aboutStar = true }
            .accessibilityAction(named: t("home.a11y.reason")) { reasonPage = true }
        }
    }

    /// The box this phone was last at, by the name every phone calls it.
    private var placeName: String {
        state.boxPlace.map(state.name(of:)) ?? t("box.unnamed")
    }

    /// "Some time for the kids." while today waits, "Today counts, for the
    /// kids." once it has; without a reason, "Some time back." and "Today
    /// counts."
    private var headline: String {
        if countedToday {
            return state.reason.map { t("home.counted.reason", "for", $0.purpose) } ?? t("home.counted")
        }
        return state.reason?.headline ?? t("home.headline")
    }

    private var countedToday: Bool { state.evenings.contains(PlainDate.local(.now)) }

    /// Days this week that counted, today's among them once it has.
    private var thisWeek: Int {
        EveningCalendar.count(EveningCalendar.week(evenings: state.evenings))
    }
}

#Preview("Home") {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return HomeView().environment(state).task { await state.load() }
}

#Preview("No box yet") {
    HomeView().environment(AppState(repo: PreviewRepository(places: []), boxPlaces: []))
}
