import Foundation

/// Guests are anonymous users with a `users/{uid}` profile of type `guest`, so they can browse, get alerts and
/// report. An account is needed only to post.
@MainActor
protocol AuthService {
    /// Emits the session whenever it changes (`nil` = no user, not even a guest). A failure means the
    /// user's profile could not be loaded. Each call returns a new stream; cancel the consuming task to stop.
    var currentUser: AsyncStream<Result<AuthSession?, AppError>> { get }

    /// Signs in anonymously and creates the guest profile with the Terms version accepted on this device.
    func signInAsGuest(acceptedTermsVersion: String, acceptedTermsAt: Date) async throws
    /// A guest is upgraded in place (same uid, so alert settings carry over); otherwise a new account is created.
    /// Success is observed through `currentUser`, not returned. New accounts are students (no organization accounts).
    func signUp(email: String, password: String, displayName: String) async throws
    /// Replaces a guest session with an existing account; the old anonymous user is deleted (best effort).
    func signIn(email: String, password: String) async throws
    func signOut() throws
    func acceptTerms(version: String) async throws
    func sendVerificationEmail() async throws
    /// Reloads the Auth user (e.g. after they tapped the verification link) and re-emits the session.
    func refreshSession() async throws
}
