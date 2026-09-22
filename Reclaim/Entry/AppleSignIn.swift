import Foundation
import AuthenticationServices
import ReclaimKit

/// Sign in with Apple is the only way in. No passwords anywhere — no reset
/// flow, no verification mail, no credential storage, no breach surface.
enum AppleSignIn {

    @MainActor
    static func complete(_ result: Result<ASAuthorization, Error>, nonce: String,
                         state: AppState) async {
        // Cancelling the sheet is a choice, not a failure: back to Welcome,
        // no banner.
        if case .failure(let error) = result,
           (error as? ASAuthorizationError)?.code == .canceled { return }

        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let repo = state.repo as? SupabaseRepository
        else {
            state.banner = t("error.signin")
            return
        }

        do {
            try await repo.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: token, nonce: nonce))

            // APPLE GIVES THE NAME EXACTLY ONCE, on the first authorization
            // ever — not the first on this device, ever. Miss it and it's gone
            // for good, including across reinstalls.
            let given = credential.fullName?.givenName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let existing = try? await repo.myProfile()
            let name = existing?.displayName ?? (given?.isEmpty == false ? given : nil)

            _ = try await repo.upsertProfile(displayName: name)
            await state.load()
        } catch {
            state.banner = t("error.signin.finish")
        }
    }
}
