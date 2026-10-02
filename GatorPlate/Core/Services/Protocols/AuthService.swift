import Foundation

nonisolated protocol AuthService: Sendable {
    /// Uid of the signed-in user, or nil.
    var currentUserID: String? { get async }

    func signUp(
        email: String,
        password: String,
        displayName: String,
        accountType: AccountType,
        orgName: String?
    ) async throws -> UserProfile

    func signIn(email: String, password: String) async throws -> UserProfile
    func signOut() async throws
}
