import SwiftUI
import ReclaimKit

/// Screen 20 — the only optional setup in the entire product.
///
/// It appears after five evenings, not at onboarding, and it must NOT read as
/// setup. Declining is permanent and costs nothing: the closing line says so,
/// and `OneTapOffer` makes it true.
struct OneTapView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("onetap.eyebrow"))
            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 24) {
                Text(t("onetap.headline"))
                    .font(Type.display(42)).foregroundStyle(Palette.ink)
                steps
                Text(t("onetap.body"))
                    .font(Type.body(14)).foregroundStyle(Palette.muted).lineSpacing(3)
            }

            Spacer(minLength: 20)
            actions
        }
        .ground()
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(1...3, id: \.self) { i in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(i)")
                        .font(Type.body(13, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(Palette.linen, in: Circle())
                        .foregroundStyle(Palette.ink2)
                    Text(t("onetap.step.\(i)"))
                        .font(Type.body(15)).foregroundStyle(Palette.ink2)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: t("onetap.primary")) { close() }
            TextAction(title: t("onetap.decline")) { close() }
            Text(t("onetap.footer"))
                .font(Type.note).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    /// Either answer is final. "We won't ask again" has to be true.
    private func close() {
        OneTapOffer.hasBeenOffered = true
        dismiss()
    }
}
