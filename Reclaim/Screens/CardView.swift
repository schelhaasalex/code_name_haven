import SwiftUI
import ReclaimKit

/// Screen 15. The card for a place: print it, or write it to a tag.
///
/// The secret in the code is the join credential, and the database keeps only
/// its hash — so this screen can only be drawn on a device that has the secret
/// in its Keychain. On any other device it says so plainly, because the card
/// already on the fridge still works and the person needs to know that more
/// than they need a broken square.
struct CardView: View {
    @Environment(AppState.self) private var state
    let placeId: UUID

    @State private var writing = false
    @State private var wrote: String?
    /// The card as a file on disk, made once. See `write(card:)`.
    @State private var file: URL?

    private var place: Place? { state.places.first { $0.id == placeId } }
    private var secret: String? { PlaceSecrets.secret(for: placeId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: t("card.eyebrow"))
                if let place, let secret {
                    card(place, url: Handle.cardURL(secret: secret))
                } else {
                    missing
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: placeId) {
            guard let place, let secret else { return }
            file = write(card: face(place, url: Handle.cardURL(secret: secret)),
                         named: place.name ?? place.handle)
        }
    }

    private func face(_ place: Place, url: URL) -> CardFace {
        CardFace(name: place.name ?? Handle.pretty(place.handle),
                 handle: place.handle,
                 url: url)
    }

    @MainActor @ViewBuilder private func card(_ place: Place, url: URL) -> some View {
        face(place, url: url)

        if let file {
            ShareLink(item: file,
                      preview: SharePreview(place.name ?? Handle.pretty(place.handle))) {
                Text(t("card.share"))
                    .font(Type.body(16, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(Palette.bone)
                    .background(Palette.ink, in: Capsule())
            }
            .buttonStyle(.plain)
        }

        TextAction(title: wrote ?? t("card.write"),
                   tint: wrote == nil ? Palette.muted : Palette.clayDeep,
                   icon: "wave.3.right") {
            write(url)
        }
        .disabled(writing)

        Text(t("card.footer"))
            .font(Type.note).foregroundStyle(Palette.muted).lineSpacing(2)
    }

    private var missing: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(place?.name ?? t("places.somewhere.title"))
                .font(Type.title).foregroundStyle(Palette.ink)
            DashedCard {
                Text(t("card.missing"))
                    .font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
            }
        }
    }

    /// The card, written to a file once, and shared as a file.
    ///
    /// It used to hand `ShareLink` a SwiftUI `Image` straight out of
    /// `ImageRenderer` — remade on every pass of `body`, so the thing the
    /// share sheet was holding could be replaced underneath it while it was
    /// open, and the tap appeared to do nothing at all.
    ///
    /// A PDF rather than an image, because this is a thing whose entire
    /// purpose is to go through a printer: it prints at whatever the printer
    /// can do instead of at the pixels a phone happened to render, and it
    /// lands in Files as a card rather than as a screenshot. Four inches by
    /// however tall it comes out, at 72 points to the inch — a postcard, which
    /// is what this is.
    @MainActor private func write(card: CardFace, named name: String) -> URL? {
        let renderer = ImageRenderer(content: card.frame(width: 288))
        let safe = name.components(separatedBy: CharacterSet(charactersIn: "/:")).joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safe.isEmpty ? "card" : safe)
            .appendingPathExtension("pdf")

        var wrote = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            wrote = true
        }
        return wrote ? url : nil
    }

    private func write(_ url: URL) {
        writing = true
        TagSession.write(url) { result in
            writing = false
            wrote = result ? t("card.write.done") : t("card.write.failed")
        }
    }
}

/// The Keychain has no secret for a preview's place, so this is the second
/// state — the one a person sees on their other device. `CardFace` previews
/// the card itself.
#Preview("No secret on this device") {
    NavigationStack { CardView(placeId: PreviewRepository.kitchenTable) }
        .environment(AppState(repo: PreviewRepository()))
}
