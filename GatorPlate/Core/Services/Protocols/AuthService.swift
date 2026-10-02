import Foundation

nonisolated protocol AuthService: Sendable {
    /// Uid of the signed-in user, or nil.
    var currentUserID: String? { get async }

    /// Emits the signed-in user's profile (or nil when signed out) now and on every session change.
    /// Finishes with an error if the session or profile cannot be loaded.
    func observeCurrentUser() -> AsyncThrowingStream<UserProfile?, any Error>

    /// Creates the account and its `users/{uid}` profile. Terms are not yet accepted on the result.
    func signUp(
        email: String,
        password: String,
        displayName: String,
        accountType: AccountType,
        orgName: String?
    ) async throws -> UserProfile

    func signIn(email: String, password: String) async throws -> UserProfile
    func signOut() async throws

    /// Stores `version` and the current time on the signed-in user's profile.
    func acceptTerms(version: String) async throws -> UserProfile
}
