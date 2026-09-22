import SwiftUI
import AuthenticationServices
import ReclaimKit

/// Screen 1.
struct WelcomeView: View {
    @Environment(AppState.self) private var state
    /// One per attempt: its hash goes to Apple, the nonce itself to Supabase.
    @State private var nonce = AppleNonce.make()

    private var invited: Bool { state.pendingInvite != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: t("app.name"))
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 22) {
                // Opened by an invite: all the app knows before sign-in is that
                // someone sent one — not who, not where.
                Text(invited ? t("welcome.invited.headline") : t("welcome.headline"))
                    .font(Type.hero)
                    .foregroundStyle(Palette.ink)
                Text(invited ? t("welcome.invited.body") : t("welcome.body"))
                    .font(Type.lede)
                    .foregroundStyle(Palette.ink2)
                    .lineSpacing(4)
            }

            Spacer(minLength: 24)

            VStack(spacing: 18) {
                SignInWithAppleButton(.continue) { request in
                    // Apple hands over the name EXACTLY ONCE, on the first
                    // authorization ever. Capture it then or lose it for good.
                    request.requestedScopes = [.fullName]
                    request.nonce = AppleNonce.hashed(nonce)
                } onCompletion: { result in
                    let used = nonce
                    nonce = AppleNonce.make()
                    Task { await AppleSignIn.complete(result, nonce: used, state: state) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(Capsule())

                Text(t("welcome.footer"))
                    .font(Type.note)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .ground()
    }
}

#Preview {
    WelcomeView().environment(AppState(repo: PreviewRepository()))
}
