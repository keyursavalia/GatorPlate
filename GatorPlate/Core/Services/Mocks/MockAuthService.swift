import Foundation

@MainActor
final class MockAuthService: AuthService {
    private(set) var user: UserProfile?
    var currentUserId: String? { user?.uid }

    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws -> UserProfile {
        let profile = UserProfile(uid: "mock-uid", displayName: displayName, email: email,
                                  accountType: accountType, orgName: orgName,
                                  acceptedTermsVersion: AppConfig.termsVersion, acceptedTermsAt: .now,
                                  notificationsEnabled: false, createdAt: .now)
        user = profile
        return profile
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        try await signUp(email: email, password: password, displayName: "Mock Student",
                         accountType: .student, orgName: nil)
    }

    func signOut() throws { user = nil }
}
