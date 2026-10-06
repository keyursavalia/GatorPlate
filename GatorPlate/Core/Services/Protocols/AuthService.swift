import Foundation

@MainActor
protocol AuthService {
    /// Emits the session whenever it changes (`nil` = signed out). A failure means the signed-in
    /// user's profile could not be loaded. Each call returns a new stream; cancel the consuming task to stop.
    var currentUser: AsyncStream<Result<AuthSession?, AppError>> { get }

    /// Success is observed through `currentUser`, not returned.
    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws
    func signIn(email: String, password: String) async throws
    func signOut() throws
    func acceptTerms(version: String) async throws
    func sendVerificationEmail() async throws
    /// Reloads the Auth user (e.g. after they tapped the verification link) and re-emits the session.
    func refreshSession() async throws
}
