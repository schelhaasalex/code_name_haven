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
    }

    @MainActor @ViewBuilder private func card(_ place: Place, url: URL) -> some View {
        let face = CardFace(name: place.name ?? Handle.pretty(place.handle),
                            handle: place.handle,
                            url: url)
        face

        if let image = rendered(face) {
            ShareLink(item: image,
                      preview: SharePreview(place.name ?? Handle.pretty(place.handle),
                                            image: image)) {
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

    /// Rendered at print scale, so what lands in the share sheet is worth
    /// putting through a printer rather than a screenshot of a phone.
    @MainActor private func rendered(_ face: CardFace) -> Image? {
        let renderer = ImageRenderer(content: face.frame(width: 320))
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:))
    }

    private func write(_ url: URL) {
        writing = true
        TagWriter.write(url) { result in
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
