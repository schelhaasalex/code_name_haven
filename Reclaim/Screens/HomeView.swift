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
            .fullScreenCover(isPresented: $scanning) { ScanView() }
        }
    }

    /// The one destination, so the link has something to say it is.
    struct Settings: Hashable {}

    /// The mark and the box, as the evening screen has them: it's where you
    /// are, not what this screen is about. Before there is one, the app's
    /// own name.
    private var header: some View {
        HStack {
            Eyebrow(text: state.boxPlace.map(state.name(of:)) ?? t("app.name"))
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
                            seed: state.skySeed)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: layout)
                VStack(spacing: 8) {
                    Text(Say.partOfDay(.now)).eyebrow(Palette.clay)
                    Text(t(countedToday ? "home.counted" : "home.headline"))
                        .font(Type.display(26)).foregroundStyle(Palette.ink)
                    Text(Say.days(total: total.count, thisWeek: thisWeek,
                                  month: Say.month(from: total.first) ?? ""))
                        .font(Type.body(14)).foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var countedToday: Bool { state.evenings.contains(PlainDate.string(from: .now)) }

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
