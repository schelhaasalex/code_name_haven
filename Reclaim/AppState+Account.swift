import Foundation
import AuthenticationServices
import ReclaimKit

/// The account: silent from the first launch, kept with an Apple ID only if
/// the person asks (Settings), and deleted on the server when they want it
/// gone.
@MainActor
extension AppState {

    /// "Keep your evenings": the Apple ID now holds this account, so a new
    /// phone or a reinstall picks up the same mark.
    func keep(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        // Cancelling the sheet is a choice, not a failure.
        if case .failure(let error) = result,
           (error as? ASAuthorizationError)?.code == .canceled { return }
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8)
        else {
            banner = t("error.retry")
            return
        }
        do {
            try await repo.keep(appleIdToken: token, nonce: nonce)
            kept = true
        } catch AccountKeeping.elsewhere {
            keptElsewhere = AppleToken(idToken: token, nonce: nonce)
        } catch {
            banner = t("error.retry")
        }
    }

    /// That Apple ID's account instead of this one. This phone's evenings so
    /// far stay in its boxes' totals; the mark becomes that account's.
    func useKeptElsewhere() async {
        guard let other = keptElsewhere else { return }
        keptElsewhere = nil
        do {
            try await repo.signIn(appleIdToken: other.idToken, nonce: other.nonce)
            session = nil; gathering = nil; memberCount = 0; startedAt = nil
            evenings = []; eveningTotal = nil
            await load()
        } catch {
            banner = t("error.retry")
        }
    }

    /// App Store guideline 5.1.1(v). The server deletes the login, and its
    /// evenings stay in the boxes' totals, owned by nobody (0020). The boxes
    /// go from this phone too: it isn't one of their people any more. A new,
    /// empty account takes this one's place on the next load. Says so once,
    /// in the banner, over the Home it leaves behind.
    @discardableResult
    public func deleteAccount() async -> Bool {
        do {
            try await repo.deleteAccount()
        } catch {
            banner = t("error.retry")
            return false
        }
        for id in boxPlaces { forget(id) }
        session = nil; gathering = nil; memberCount = 0; startedAt = nil
        evenings = []; eveningTotal = nil; kept = nil
        await load()
        banner = t("settings.deleted")
        return true
    }
}
