import SwiftUI
import ReclaimKit

/// Screen 2 — Home: the box you were last at, your evenings as the mark with
/// today's star among them, and your week. With no box yet, the one thing
/// there is to do: meet it.
///
/// The mark is the point: today's star waits as an outline until today has
/// counted, and every evening that counts stays. What each box has kept is
/// the long view, on the box's own page in Settings — not the reason to set
/// the phone down tonight.
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
                    Spacer(minLength: 16)
                } else {
                    box
                    Spacer(minLength: 16)
                    today
                    Spacer(minLength: 16)
                }
                week
            }
            .ground()
            .navigationDestination(for: Settings.self) { _ in SettingsView() }
            .fullScreenCover(isPresented: $scanning) { ScanView() }
        }
    }

    /// The one destination, so the link has something to say it is.
    struct Settings: Hashable {}

    private var header: some View {
        HStack {
            Eyebrow(text: t("app.name"))
            Spacer()
            NavigationLink(value: Settings()) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 19)).foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(t("home.a11y.settings"))
        }
    }

    private var box: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Say.partOfDay(.now)).eyebrow(Palette.clay)
            Text(state.boxPlace.map(state.name(of:)) ?? t("box.unnamed"))
                .font(Type.display(36)).foregroundStyle(Palette.ink)
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
    /// said how many — a guessed mark would be a lie.
    @ViewBuilder private var today: some View {
        if let total = state.eveningTotal {
            let layout = EveningMarkLayout.today(total: total.count, counted: countedToday)
            VStack(spacing: 20) {
                EveningMark(layout: layout, size: 200, seed: state.skySeed)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: layout)
                VStack(spacing: 6) {
                    Text(t(countedToday ? "home.counted" : "home.headline"))
                        .font(Type.display(26)).foregroundStyle(Palette.ink)
                    Text(eveningsLine(total))
                        .font(Type.body(14)).foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var countedToday: Bool { state.evenings.contains(PlainDate.string(from: .now)) }

    /// The words beside the mark carry the number; before the first evening,
    /// what to do.
    private func eveningsLine(_ total: EveningTotal) -> String {
        let month = Say.month(from: total.first) ?? ""
        switch total.count {
        case 0:     return t("home.body")
        case 1:     return t("home.evenings.one", "month", month)
        case let n: return t("home.evenings", "count", Say.number(n), "month", month)
        }
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("home.week.label")).eyebrow(Palette.muted)
            HStack(spacing: 12) {
                Text(weekLine).font(Type.body(15)).foregroundStyle(Palette.ink2)
                Spacer(minLength: 8)
                DotWeek(days: weekDots)
            }
        }
        .accessibilityElement(children: .combine)
        .frame(minHeight: 44)
        .padding(.top, 18)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        .padding(.top, 24)
    }

    private var weekDots: [EveningCalendar.Day] {
        EveningCalendar.week(evenings: state.evenings)
    }

    /// Never "no evenings this week": a week that hasn't had one yet is ahead
    /// of you, not behind.
    private var weekLine: String {
        switch EveningCalendar.count(weekDots) {
        case 0:     t("home.footer.none")
        case 1:     t("home.footer.one")
        case let n: t("home.footer", "count", Say.number(n))
        }
    }
}

#Preview("Home") {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return HomeView().environment(state).task { await state.load() }
}

#Preview("No box yet") {
    HomeView().environment(AppState(repo: PreviewRepository(places: []), boxPlaces: []))
}
