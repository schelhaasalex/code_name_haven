import SwiftUI
import ReclaimKit

/// Screens 2 and 11 — Home, and Home when there's nothing in it yet.
///
/// The root of the app. NO TAB BAR: a tab bar advertises that there's something
/// to browse, which is the one thing this app shouldn't say. Places and settings
/// sit in the header; your rhythm is the footer.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var route: Route?
    @State private var inviting = false

    private var isDayOne: Bool { state.places.isEmpty && state.rhythm.longestRunDays == 0 }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 20)
                if isDayOne { dayOne } else { usual }
                Spacer(minLength: 20)
                actions
                // Always, day one included: it's the only way to the rhythm,
                // and seven empty circles are true on a first day too.
                footer
            }
            .ground()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .places:            PlacesView()
                case .rhythm:            RhythmView()
                case .settings:          SettingsView()
                case .place(let place):  PlaceView(place: place)
                case .card(let id):      CardView(placeId: id)
                }
            }
            .sheet(isPresented: $inviting) { InviteSheet(place: nil) }
            .sheet(item: Binding(get: { state.pending }, set: { _ in state.dismissInterruption() })) {
                InterruptionRouter(interruption: $0)
            }
        }
    }

    private var header: some View {
        HStack {
            Eyebrow(text: t("app.name"))
            Spacer()
            HStack(spacing: 4) {
                NavigationLink(value: Route.places) {
                    // A table: what most places are. Never a pin — nothing in
                    // this app reads where you are.
                    Image(systemName: "table.furniture")
                        .font(.system(size: 19)).foregroundStyle(Palette.ink2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(t("home.a11y.places"))

                NavigationLink(value: Route.settings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 19)).foregroundStyle(Palette.ink2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(t("home.a11y.settings"))
            }
        }
    }

    private var usual: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Say.partOfDay(.now)).eyebrow(Palette.clay)
            Text(t("home.headline")).font(Type.hero).foregroundStyle(Palette.ink)
            Text(t("home.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
        }
    }

    private var dayOne: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("dayone.headline")).font(Type.hero).foregroundStyle(Palette.ink)
            Text(t("dayone.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(4)
        }
    }

    private var actions: some View {
        VStack(spacing: 20) {
            PrimaryButton(title: t("home.primary")) {
                Task { await state.setItDown() }
            }

            if !isDayOne, let place = state.usualPlace, let name = place.name {
                suggestion(place: place, name: name)
            }
            // Until someone else shares one of your places — day one or not.
            // A line, not a card: it shouldn't compete with setting it down.
            if !state.hasCompany {
                TextAction(title: t("home.invite"), icon: "person.badge.plus") { inviting = true }
            }
        }
    }

    private func suggestion(place: Place, name: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await state.setItDown(place: place.id) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .foregroundStyle(Palette.clay)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("home.suggestion.title", "place", name))
                            .font(Type.body(16, weight: .medium))
                            .foregroundStyle(Palette.ink)
                        Text(t("home.suggestion.body"))
                            .font(Type.note).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.hairline)
                }
                .padding(16)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1) }
            }
            .buttonStyle(.plain)

            // Said plainly rather than implied: this is history, not location.
            Text(t("home.suggestion.note"))
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
                .padding(.horizontal, 4)
        }
    }


    /// The way to the rhythm (screen 10). Labelled like every other section,
    /// with a chevron you can see, so it reads as somewhere to go — it used to
    /// be a line of text and some dots, and nobody found it.
    private var footer: some View {
        NavigationLink(value: Route.rhythm) {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("home.rhythm.label")).eyebrow(Palette.muted)
                HStack(spacing: 12) {
                    Text(footerLine)
                        .font(Type.body(15)).foregroundStyle(Palette.ink2)
                    Spacer(minLength: 8)
                    DotWeek(days: weekDots)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(minHeight: 44)
            .padding(.top, 18)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
    }

    private var weekDots: [EveningCalendar.Day] {
        EveningCalendar.week(evenings: state.evenings)
    }

    private var eveningsThisWeek: Int { EveningCalendar.count(weekDots) }

    /// Never "no evenings this week": a week that hasn't had one yet is ahead
    /// of you, not behind.
    private var footerLine: String {
        switch eveningsThisWeek {
        case 0:     t("home.footer.none")
        case 1:     t("home.footer.one")
        case let n: t("home.footer", "count", Say.number(n))
        }
    }
}

#Preview("Home") {
    HomeView().environment(AppState(repo: PreviewRepository()))
}

#Preview("Day one") {
    HomeView().environment(AppState(repo: PreviewRepository(places: [])))
}
