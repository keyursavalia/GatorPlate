import Foundation

nonisolated struct MockAuthService: AuthService {
    var currentUserID: String? { get async { SampleData.profile.uid } }

    func signUp(
        email: String,
        password: String,
        displayName: String,
        accountType: AccountType,
        orgName: String?
    ) async throws -> UserProfile {
        SampleData.profile
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        SampleData.profile
    }

    func signOut() async throws {}
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
