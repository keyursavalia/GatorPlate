import Foundation

#if DEBUG
@MainActor
final class MockPostService: PostService {
    private(set) var posts: [FoodPost]
    private let images: any ImageStore
    private var continuations: [UUID: AsyncThrowingStream<PostsSnapshot, Error>.Continuation] = [:]
    /// Set to make `publish` fail.
    var publishError: AppError?

    init(posts: [FoodPost] = [.sample], images: any ImageStore = MockImageStore()) {
        self.posts = posts
        self.images = images
    }

    func observeActivePosts() -> AsyncThrowingStream<PostsSnapshot, Error> {
        let (stream, continuation) = AsyncThrowingStream<PostsSnapshot, Error>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        continuation.yield(PostsSnapshot(posts: posts, isFromCache: false))
        return stream
    }

    /// Pushes a snapshot to every listener, like a Firestore change.
    func send(_ snapshot: PostsSnapshot) {
        for continuation in continuations.values { continuation.yield(snapshot) }
    }

    private func broadcast() {
        send(PostsSnapshot(posts: posts, isFromCache: false))
    }

    func fetchPost(id: String) async throws -> FoodPost? {
        posts.first { $0.id == id }
    }

    /// Firestore-style ID: 20 alphanumeric characters (also what `storage.rules` accepts).
    func makePostId() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<20).compactMap { _ in alphabet.randomElement() })
    }

    func publish(_ submission: PostSubmission, photos: [Data?]) async throws -> PublishResult {
        try await Task.sleep(for: .milliseconds(600))
        if let publishError { throw publishError }
        var slots: [Int] = []
        for (slot, jpeg) in photos.enumerated() {
            guard let jpeg else { continue }
            if (try? await images.save(jpeg: jpeg, forPostId: submission.postId, slot: slot)) != nil {
                slots.append(slot)
            }
        }
        let now = Date.now
        let post = FoodPost(submission: submission, photoSlots: slots, createdAt: now,
                            expiresAt: now.addingTimeInterval(Double(submission.durationMinutes) * 60))
        posts.removeAll { $0.id == post.id }
        posts.append(post)
        broadcast()
        return PublishResult(post: post, requestedPhotos: photos.count)
    }

    func markGone(postId: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { throw AppError.validation("Post not found") }
        posts[index].status = .gone
        posts[index].updatedAt = .now
        broadcast()
    }

    func report(postId: String, category: ReportCategory, reason: String) async throws {}
    func appeal(message: String, bannedUntil: Date) async throws {}
    /// What `postingBan()` returns (to show the "Posting paused" sheet).
    var ban: PostingBan?
    func postingBan() async -> PostingBan? { ban }
}

extension FoodPost {
    /// Sample data for mocks.
    nonisolated static var sample: FoodPost {
        mock(id: "sample-post", title: "Pad Thai - SSB 201",
             description: "Leftover pad thai from the club meeting.", buildingId: "ssb", room: "Room 201",
             items: [FoodItem(name: "Pad Thai", dietary: .vegan, calories: CalorieRange(low: 420, high: 520))],
             dietary: .vegan, allergens: [.soy, .peanuts], minutesLeft: 30)
    }

    private nonisolated static func mock(
        id: String, title: String, description: String, buildingId: String, room: String?,
        items: [FoodItem], dietary: DietaryClass, allergens: [Allergen], minutesLeft: Int
    ) -> FoodPost {
        let now = Date.now
        let building = CampusBuilding.byId(buildingId)
        return FoodPost(
            id: id, authorUid: "mock-uid", authorName: "Mock Student", orgName: "Mock Club",
            title: title, description: description,
            items: items, overallDietary: dietary, allergenWarnings: allergens, cautions: [], estimatedServings: 10,
            buildingId: buildingId, locationName: building?.name ?? buildingId, locationDetail: room,
            latitude: building?.coordinate.latitude ?? SFSUCampus.homeCoordinate.latitude,
            longitude: building?.coordinate.longitude ?? SFSUCampus.homeCoordinate.longitude,
            photoSlots: [], aiGenerated: false, editedAfterAI: false,
            status: .active, createdAt: now.addingTimeInterval(-10 * 60),
            expiresAt: now.addingTimeInterval(Double(minutesLeft) * 60), updatedAt: now)
    }
}
#endif
