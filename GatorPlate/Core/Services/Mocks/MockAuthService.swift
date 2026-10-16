import Foundation

@MainActor
final class MockAuthService: AuthService {
    private typealias Event = Result<AuthSession?, AppError>

    private var session: AuthSession?
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    init(session: AuthSession? = nil) {
        self.session = session
    }

    var currentUser: AsyncStream<Result<AuthSession?, AppError>> {
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        continuation.yield(.success(session))
        return stream
    }

    func signInAsGuest(acceptedTermsVersion: String, acceptedTermsAt: Date) async throws {
        let profile = UserProfile(uid: "mock-guest-uid", displayName: AccountType.guest.displayName, email: nil,
                                  accountType: .guest, orgName: nil, acceptedTermsVersion: acceptedTermsVersion,
                                  acceptedTermsAt: acceptedTermsAt, notificationsEnabled: false, createdAt: .now)
        set(AuthSession(profile: profile, isEmailVerified: false))
    }

    /// A guest keeps its uid and alert settings, like the live upgrade.
    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws {
        var profile = session?.profile ?? UserProfile(uid: "mock-uid", displayName: displayName, email: email,
                                                      accountType: accountType, orgName: orgName,
                                                      acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                                      notificationsEnabled: false, createdAt: .now)
        profile.displayName = displayName
        profile.email = email
        profile.accountType = accountType
        profile.orgName = orgName
        profile.createdAt = .now
        set(AuthSession(profile: profile, isEmailVerified: !AppConfig.requireEmailVerification))
    }

    func signIn(email: String, password: String) async throws {
        let profile = UserProfile(uid: "mock-uid", displayName: "Mock Student", email: email,
                                  accountType: .student, orgName: nil, acceptedTermsVersion: AppConfig.termsVersion,
                                  acceptedTermsAt: .now, notificationsEnabled: false, createdAt: .now)
        set(AuthSession(profile: profile, isEmailVerified: true))
    }

    func signOut() throws { set(nil) }

    func acceptTerms(version: String) async throws {
        guard var current = session else { throw AppError.unauthorized }
        current.profile.acceptedTermsVersion = version
        current.profile.acceptedTermsAt = .now
        set(current)
    }

    func sendVerificationEmail() async throws {}

    func refreshSession() async throws {
        guard var current = session else { return }
        current.isEmailVerified = true
        set(current)
    }

    private func set(_ newSession: AuthSession?) {
        session = newSession
        for continuation in continuations.values { continuation.yield(.success(newSession)) }
    }
}
