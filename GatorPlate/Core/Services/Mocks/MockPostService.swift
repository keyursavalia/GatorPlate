import Foundation

@MainActor
final class MockPostService: PostService {
    private(set) var posts: [FoodPost]

    init(posts: [FoodPost] = [.sample]) {
        self.posts = posts
    }

    func observeActivePosts() -> AsyncThrowingStream<[FoodPost], Error> {
        let snapshot = posts
        return AsyncThrowingStream { $0.yield(snapshot) }
    }

    func createPost(_ post: FoodPost) async throws { posts.append(post) }

    func markGone(postId: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { throw AppError.validation("Post not found") }
        posts[index].status = .gone
        posts[index].updatedAt = .now
    }

    func report(postId: String, reason: String) async throws {}
}

extension FoodPost {
    /// Sample data for mocks and previews.
    nonisolated static var sample: FoodPost {
        let now = Date.now
        return FoodPost(
            id: "sample-post", authorUid: "mock-uid", authorName: "Mock Student", orgName: "Mock Club",
            title: "Pad Thai", description: "Leftover pad thai from the club meeting.",
            items: [FoodItem(name: "Pad Thai", dietary: .vegan, calories: CalorieRange(low: 420, high: 520))],
            overallDietary: .vegan, allergenWarnings: [.soy, .peanuts], cautions: [], estimatedServings: 10,
            buildingId: "ssb", locationName: "Science & Social Sciences Building", locationDetail: "Room 201",
            latitude: 37.7219, longitude: -122.4782,
            hasPhoto: false, aiGenerated: false, editedAfterAI: false,
            status: .active, createdAt: now, expiresAt: now.addingTimeInterval(30 * 60), updatedAt: now)
    }
}
