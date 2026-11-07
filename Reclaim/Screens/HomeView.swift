import SwiftUI
import ReclaimKit

/// Screen 2 — Home: the box, what it has kept, and your week. With no box yet,
/// the one thing there is to do: meet it.
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
                Spacer(minLength: 20)
                if state.boxPlace == nil { pair } else { box }
                Spacer(minLength: 20)
                if state.boxPlace != nil { kept }
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
        VStack(alignment: .leading, spacing: 16) {
            Text(Say.partOfDay(.now)).eyebrow(Palette.clay)
            Text(state.box?.name ?? t("box.unnamed")).font(Type.hero).foregroundStyle(Palette.ink)
            Text(t("home.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
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

    /// The total that only grows: every evening anyone has had at the box.
    /// Nothing until the database has said — a guessed zero would be a lie.
    @ViewBuilder private var kept: some View {
        if let summary = state.boxSummary {
            PaperCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t(BoxStage.key(summary.stage))).eyebrow(Palette.clay)
                    Text(keptLine(summary))
                        .font(Type.display(22)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func keptLine(_ summary: PlaceSummary) -> String {
        let hours = Say.spokenDuration(minutes: summary.wallClockMinutes)
        switch summary.evenings {
        case 0:     return t("home.kept.none")
        case 1:     return t("home.kept.one", "duration", hours)
        case let n: return t("home.kept", "duration", hours, "count", Say.number(n))
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
    let state = AppState(repo: PreviewRepository(), boxPlace: PreviewRepository.kitchenTable)
    return HomeView().environment(state).task { await state.load() }
}

#Preview("No box yet") {
    HomeView().environment(AppState(repo: PreviewRepository(places: []), boxPlace: nil))
}
