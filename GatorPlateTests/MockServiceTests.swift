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

    @Test func openStreamFollowsPublishAndMarkGone() async throws {
        let service = MockPostService(posts: [], keepsStreamOpen: true)
        let received = Received()
        let task = Task {
            for await posts in service.observeActivePosts() { await received.add(posts.map(\.id)) }
        }
        // Wait until the stream is registered, so no change can slip in before it.
        while await service.observerCount == 0 { try await Task.sleep(for: .milliseconds(5)) }
        _ = try await service.publish(SampleData.post(id: "a"), imageJPEG: nil)
        try await service.markGone(postID: "a")

        for _ in 0..<200 {
            if await received.count >= 3 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        task.cancel()
        #expect(await received.snapshots == [[], ["a"], []])
    }

    @Test func mockEnvironmentIsNotFirebaseConfigured() {
        #expect(!AppEnvironment.mock.isFirebaseConfigured)
        #expect(AppEnvironment.live(firebaseConfigured: true).isFirebaseConfigured)
    }
}

private actor Received {
    private(set) var snapshots: [[String]] = []
    var count: Int { snapshots.count }
    func add(_ ids: [String]) { snapshots.append(ids) }
}
