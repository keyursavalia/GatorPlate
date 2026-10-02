import Foundation
import Testing
@testable import GatorPlate

@MainActor
private final class TestClock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

@MainActor
struct PostsRepositoryTests {
    /// Real "now": the mock service filters with the real clock, so the fixtures must be live in real time too.
    private let start = Date()

    private func post(
        _ id: String,
        createdAgo: TimeInterval = 0,
        expiresIn: TimeInterval = 600,
        status: PostStatus = .active
    ) -> FoodPost {
        var post = SampleData.post(now: start, id: id)
        post.createdAt = start.addingTimeInterval(-createdAgo)
        post.expiresAt = start.addingTimeInterval(expiresIn)
        post.status = status
        return post
    }

    private func makeRepository(
        service: any PostService = MockPostService(posts: []),
        clock: TestClock
    ) -> PostsRepository {
        PostsRepository(
            service: service,
            now: { clock.date },
            refreshInterval: .milliseconds(20),
            loadFallback: .milliseconds(50)
        )
    }

    // MARK: Filtering and sorting

    @Test func filtersOutExpiredAndGonePosts() {
        let clock = TestClock(start)
        let repository = makeRepository(clock: clock)
        repository.apply(snapshot: [
            post("live"),
            post("expired", expiresIn: -1),
            post("at-boundary", expiresIn: 0),
            post("gone", status: .gone)
        ])
        #expect(repository.posts.map(\.id) == ["live"])
    }

    @Test func sortsNewestFirstWithIdTieBreak() {
        let clock = TestClock(start)
        let repository = makeRepository(clock: clock)
        repository.apply(snapshot: [
            post("old", createdAgo: 600),
            post("b", createdAgo: 60),
            post("a", createdAgo: 60),
            post("newest", createdAgo: 5)
        ])
        #expect(repository.posts.map(\.id) == ["newest", "a", "b", "old"])
    }

    // MARK: Expiry without a server

    @Test func aPostVanishesWhenTheClockPassesItsExpiry() {
        let clock = TestClock(start)
        let repository = makeRepository(clock: clock)
        repository.apply(snapshot: [post("short", expiresIn: 60), post("long", expiresIn: 1800)])
        #expect(repository.posts.count == 2)

        clock.date = start.addingTimeInterval(59)
        repository.refresh()
        #expect(repository.posts.count == 2)

        clock.date = start.addingTimeInterval(60)
        repository.refresh()
        #expect(repository.posts.map(\.id) == ["long"])
    }

    @Test func theTickerExpiresPostsWithoutANewSnapshot() async {
        let clock = TestClock(start)
        let service = MockPostService(posts: [post("short", expiresIn: 60)])
        let repository = makeRepository(service: service, clock: clock)
        let task = Task { await repository.run() }
        #expect(await waitUntil { repository.posts.count == 1 })

        clock.date = start.addingTimeInterval(120)
        let vanished = await waitUntil { repository.posts.isEmpty }
        task.cancel()
        #expect(vanished)
    }

    // MARK: Snapshots

    @Test func anIdenticalSnapshotLeavesTheVisibleListUnchanged() {
        let clock = TestClock(start)
        let repository = makeRepository(clock: clock)
        let snapshot = [post("a"), post("b", createdAgo: 30)]
        repository.apply(snapshot: snapshot)
        let before = repository.posts
        repository.apply(snapshot: snapshot)
        #expect(repository.posts == before)
    }

    @Test func hasLoadedFlipsOnTheFirstSnapshotEvenWhenEmpty() {
        let clock = TestClock(start)
        let repository = makeRepository(clock: clock)
        #expect(!repository.hasLoaded)
        repository.apply(snapshot: [])
        #expect(repository.hasLoaded)
    }

    @Test func hasLoadedFlipsAfterTheFallbackWhenNothingArrives() async {
        let clock = TestClock(start)
        // A stream that never yields (offline).
        let offline = makeRepository(service: SilentPostService(), clock: clock)
        let task = Task { await offline.run() }
        #expect(!offline.hasLoaded)
        let loaded = await waitUntil { offline.hasLoaded }
        task.cancel()
        #expect(loaded)
    }

    // MARK: Realtime and lifecycle

    @Test func runShowsPostsFromTheServiceAndFollowsMarkGone() async throws {
        let clock = TestClock(start)
        let service = MockPostService(posts: [post("a"), post("b", createdAgo: 10)], keepsStreamOpen: true)
        let repository = makeRepository(service: service, clock: clock)
        let task = Task { await repository.run() }

        #expect(await waitUntil { repository.posts.count == 2 })
        try await service.markGone(postID: "a")
        #expect(await waitUntil { repository.posts.map(\.id) == ["b"] })

        _ = try await service.publish(post("c", createdAgo: -5), imageJPEG: nil)
        #expect(await waitUntil { repository.posts.map(\.id) == ["c", "b"] })
        task.cancel()
    }

    @Test func cancellingRunStopsTheListener() async {
        let clock = TestClock(start)
        let service = MockPostService(posts: [post("a")], keepsStreamOpen: true)
        let repository = makeRepository(service: service, clock: clock)
        let task = Task { await repository.run() }
        #expect(await waitUntil { repository.posts.count == 1 })
        #expect(await service.observerCount == 1)

        task.cancel()
        await task.value
        var stopped = false
        for _ in 0..<200 {
            stopped = await service.observerCount == 0
            if stopped { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(stopped)
    }

    @Test func callingRunTwiceCreatesOnlyOneListener() async {
        let clock = TestClock(start)
        let service = MockPostService(posts: [post("a")], keepsStreamOpen: true)
        let repository = makeRepository(service: service, clock: clock)
        let first = Task { await repository.run() }
        #expect(await waitUntil { repository.posts.count == 1 })
        let second = Task { await repository.run() }
        await second.value
        #expect(await service.observerCount == 1)
        first.cancel()
    }
}

/// A listener that never reports anything, like a device with no connection and an empty cache.
private nonisolated struct SilentPostService: PostService {
    func observeActivePosts() -> AsyncStream<[FoodPost]> { AsyncStream { _ in } }
    func publish(_ post: FoodPost, imageJPEG: Data?) async throws -> FoodPost { post }
    func markGone(postID: String) async throws {}
    func report(postID: String, reason: String) async throws {}
}
