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

    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws {
        let profile = UserProfile(uid: "mock-uid", displayName: displayName, email: email,
                                  accountType: accountType, orgName: orgName,
                                  acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                  notificationsEnabled: false, createdAt: .now)
        set(AuthSession(profile: profile, isEmailVerified: !AppConfig.requireEmailVerification))
    }

    func signIn(email: String, password: String) async throws {
        try await signUp(email: email, password: password, displayName: "Mock Student",
                         accountType: .student, orgName: nil)
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
