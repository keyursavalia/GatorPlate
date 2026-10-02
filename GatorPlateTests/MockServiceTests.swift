import Testing
@testable import GatorPlate

struct MockServiceTests {
    @Test func publishedPostAppearsInActiveFeed() async throws {
        let service = MockPostService(posts: [])
        _ = try await service.publish(SampleData.post(id: "a"), imageJPEG: nil)

        var latest: [FoodPost] = []
        for await posts in service.observeActivePosts() { latest = posts }
        #expect(latest.map(\.id) == ["a"])
    }

    @Test func markedGonePostLeavesActiveFeed() async throws {
        let service = MockPostService(posts: [SampleData.post(id: "a")])
        try await service.markGone(postID: "a")

        var latest: [FoodPost] = [SampleData.post()]
        for await posts in service.observeActivePosts() { latest = posts }
        #expect(latest.isEmpty)
    }

    @Test func markGoneUnknownPostThrowsValidation() async {
        let service = MockPostService(posts: [])
        await #expect(throws: AppError.validation("Post not found")) {
            try await service.markGone(postID: "missing")
        }
    }

    @Test func mockEnvironmentIsNotFirebaseConfigured() {
        #expect(!AppEnvironment.mock.isFirebaseConfigured)
        #expect(AppEnvironment.live(firebaseConfigured: true).isFirebaseConfigured)
    }
}
