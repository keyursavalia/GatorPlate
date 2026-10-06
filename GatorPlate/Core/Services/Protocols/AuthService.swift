import Foundation

@MainActor
protocol AuthService {
    var currentUserId: String? { get }
    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws -> UserProfile
    func signIn(email: String, password: String) async throws -> UserProfile
    func signOut() throws
}
