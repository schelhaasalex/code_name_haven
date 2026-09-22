import SwiftUI
import ReclaimKit

/// Inviting someone to a place. People are connected only through places, so
/// an invite is always to one: from a place's screen it's that place; on day
/// one, with none yet, it starts by asking where you two usually sit.
///
/// The link joins the place and starts nothing, and it works for a week — the
/// note says so, because anyone it's forwarded to can join too.
struct InviteSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    /// Nil from day one or anywhere without a place in hand.
    let place: Place?

    @State private var chosen: Place?
    @State private var link: URL?
    @State private var name = ""
    @State private var working = false
    /// Said here, in the sheet. AppState's banner sits on the screen under
    /// it, so a failure used to look like a button that did nothing.
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("invite.eyebrow"))
            Group {
                if let chosen {
                    ready(chosen)
                } else if place == nil && state.places.isEmpty {
                    naming
                } else if place == nil {
                    picking
                }
            }
            .padding(.top, 28)

            Spacer(minLength: 16)
            TextAction(title: t("invite.close")) { dismiss() }
        }
        .ground()
        .task { if let place { await choose(place) } }
    }

    private var naming: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(t("invite.name.title")).font(Type.title).foregroundStyle(Palette.ink)
            Text(t("invite.name.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(3)
            TextField(t("invite.name.placeholder"), text: $name)
                .font(Type.display(24)).foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
            if failed {
                Text(t("error.retry")).font(Type.note).foregroundStyle(Palette.clayDeep)
            }
            PrimaryButton(title: t("invite.name.action")) {
                let named = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !named.isEmpty, !working else { return }
                working = true
                failed = false
                Task {
                    if let made = await state.makePlace(named: named) {
                        await choose(made)
                    } else {
                        failed = true
                    }
                    working = false
                }
            }
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            .padding(.top, 8)
        }
    }

    private var picking: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("invite.pick.title")).font(Type.title).foregroundStyle(Palette.ink)
            PaperCard {
                VStack(spacing: 0) {
                    ForEach(ordered) { place in
                        Button { Task { await choose(place) } } label: {
                            HStack {
                                Text(label(place)).font(Type.body(16, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13))
                                    .foregroundStyle(Palette.hairline)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func ready(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(t("invite.title", "place", label(place))).font(Type.title).foregroundStyle(Palette.ink)
            Text(t("invite.body")).font(Type.lede).foregroundStyle(Palette.ink2).lineSpacing(3)
            if let link {
                // One piece of plain text with the link in it. Shared as a URL
                // plus a message, some apps received the URL as an archived
                // object and pasted "bplist00…" into a friend's chat. Messages
                // still turns the link in text into a preview.
                ShareLink(item: t("invite.message", "place", label(place), "link", link.absoluteString),
                          subject: Text(t("invite.subject", "place", label(place)))) {
                    Text(t("invite.send"))
                        .font(Type.body(17, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .foregroundStyle(Palette.bone)
                        .background(Palette.ink, in: Capsule())
                }
                .padding(.top, 8)
            } else if failed {
                Text(t("error.retry")).font(Type.note).foregroundStyle(Palette.clayDeep)
                QuietButton(title: t("invite.retry")) { Task { await choose(place) } }
            } else {
                Text(t("invite.preparing")).font(Type.note).foregroundStyle(Palette.muted)
            }
            Text(t("invite.note", "place", label(place)))
                .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
        }
    }

    /// The usual place first: it's the likeliest one to be shared.
    private var ordered: [Place] {
        let usual = state.usualPlace
        return (usual.map { [$0] } ?? []) + state.places.filter { $0.id != usual?.id }
    }

    private func label(_ place: Place) -> String { place.name ?? Handle.pretty(place.handle) }

    private func choose(_ place: Place) async {
        chosen = place
        failed = false
        link = await state.inviteLink(to: place.id)
        failed = link == nil
    }
}

#Preview("Day one") {
    InviteSheet(place: nil).environment(AppState(repo: PreviewRepository(places: [])))
}

#Preview("From a place") {
    InviteSheet(place: Place(id: PreviewRepository.kitchenTable, name: "The Kitchen Table",
                             handle: "amber-otter"))
        .environment(AppState(repo: PreviewRepository()))
}
