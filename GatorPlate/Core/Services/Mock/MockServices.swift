import Foundation

/// In-memory auth. Starts signed out unless seeded; failures can be injected per operation.
actor MockAuthService: AuthService {
    nonisolated struct Failures: Sendable {
        var session: AppError?
        var signUp: AppError?
        var signIn: AppError?
        var signOut: AppError?
        var acceptTerms: AppError?
    }

    private nonisolated struct Account {
        var password: String
        var profile: UserProfile
    }

    private var accounts: [String: Account] = [:]
    private var current: UserProfile?
    private var failures: Failures
    private var continuations: [UUID: AsyncThrowingStream<UserProfile?, any Error>.Continuation] = [:]
    private let keepsStreamOpen: Bool
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - signedInAs: Seeds an existing session (and an account for it).
    ///   - keepsStreamOpen: When false the stream yields the current state and finishes (launch-state tests).
    init(
        signedInAs profile: UserProfile? = nil,
        failures: Failures = Failures(),
        keepsStreamOpen: Bool = true,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.current = profile
        self.failures = failures
        self.keepsStreamOpen = keepsStreamOpen
        self.now = now
        if let profile {
            accounts[profile.email] = Account(password: "password1", profile: profile)
        }
    }

    var currentUserID: String? { current?.uid }

    func setFailures(_ failures: Failures) {
        self.failures = failures
    }

    /// Test hook: simulates the session changing outside the app (e.g. signed out elsewhere).
    func simulateExternalSignOut() {
        current = nil
        emit(nil)
    }

    nonisolated func observeCurrentUser() -> AsyncThrowingStream<UserProfile?, any Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            let task = Task {
                await self.register(continuation, id: id)
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.unregister(id) }
            }
        }
    }

    func signUp(
        email: String,
        password: String,
        displayName: String,
        accountType: AccountType,
        orgName: String?
    ) async throws -> UserProfile {
        if let error = failures.signUp { throw error }
        let key = AuthValidation.normalizedEmail(email)
        guard accounts[key] == nil else { throw AppError.emailInUse }
        guard AuthValidation.isValidPassword(password) else { throw AppError.weakPassword }

        let profile = UserProfile(
            uid: "mock-\(accounts.count + 1)",
            displayName: displayName,
            email: key,
            accountType: accountType,
            orgName: orgName,
            acceptedTermsVersion: nil,
            acceptedTermsAt: nil,
            notificationsEnabled: false,
            createdAt: now()
        )
        accounts[key] = Account(password: password, profile: profile)
        current = profile
        emit(profile)
        return profile
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        if let error = failures.signIn { throw error }
        guard let account = accounts[AuthValidation.normalizedEmail(email)], account.password == password else {
            throw AppError.invalidCredentials
        }
        current = account.profile
        emit(account.profile)
        return account.profile
    }

    func signOut() async throws {
        if let error = failures.signOut { throw error }
        current = nil
        emit(nil)
    }

    func acceptTerms(version: String) async throws -> UserProfile {
        if let error = failures.acceptTerms { throw error }
        guard var profile = current else { throw AppError.unauthorized }
        profile.acceptedTermsVersion = version
        profile.acceptedTermsAt = now()
        current = profile
        accounts[profile.email]?.profile = profile
        emit(profile)
        return profile
    }

    private func register(_ continuation: AsyncThrowingStream<UserProfile?, any Error>.Continuation, id: UUID) {
        if let error = failures.session {
            continuation.finish(throwing: error)
            return
        }
        continuation.yield(current)
        if keepsStreamOpen {
            continuations[id] = continuation
        } else {
            continuation.finish()
        }
    }

    private func unregister(_ id: UUID) {
        continuations[id] = nil
    }

    private func emit(_ profile: UserProfile?) {
        for continuation in continuations.values {
            continuation.yield(profile)
        }
    }
}

actor MockPostService: PostService {
    private var posts: [FoodPost]

    init(posts: [FoodPost] = [SampleData.post()]) {
        self.posts = posts
    }

    nonisolated func observeActivePosts() -> AsyncStream<[FoodPost]> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(await self.activePosts())
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func publish(_ post: FoodPost) async throws {
        posts.append(post)
    }

    func markGone(postID: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw AppError.validation("Post not found")
        }
        posts[index].status = .gone
    }

    private func activePosts() -> [FoodPost] {
        posts.filter { $0.isActive() }
    }
}

nonisolated struct MockFoodAnalyzer: FoodAnalyzing {
    func analyze(imageJPEG: Data) async throws -> FoodAnalysisResult {
        SampleData.analysis
    }
}

nonisolated struct MockLocationProvider: LocationProviding {
    func currentLocation() async throws -> Coordinate {
        SampleData.campusCoordinate
    }
}

actor MockImageStore: ImageStore {
    private var images: [String: Data] = [:]

    func save(jpeg: Data, forPostID postID: String) async throws {
        images[postID] = jpeg
    }

    func load(forPostID postID: String) async throws -> Data? {
        images[postID]
    }
}
