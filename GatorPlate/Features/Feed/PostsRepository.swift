import Foundation
import Observation
import OSLog

/// The one place the app listens to active posts. The map and the Feed both read `posts`.
///
/// Lifecycle: `run()` is called from a `.task` on the signed-in main UI. Cancelling that task (sign-out removes the
/// UI) ends the stream, which removes the Firestore listener. Expiry needs no server: a ticker re-evaluates
/// `FoodPost.isActive(now:)` every few seconds.
@MainActor
@Observable
final class PostsRepository {
    /// Active posts, newest first. Only reassigned when the visible set actually changes, so a snapshot that
    /// repeats the same data (cache, then server) or a timer tick with nothing expired does not invalidate views.
    private(set) var posts: [FoodPost] = []
    /// True after the first snapshot, or after the fallback delay (offline), so the Feed can tell "loading" from "empty".
    private(set) var hasLoaded = false

    @ObservationIgnored private var snapshot: [FoodPost] = []
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private let service: any PostService
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let refreshInterval: Duration
    @ObservationIgnored private let loadFallback: Duration

    init(
        service: any PostService,
        now: @escaping @MainActor () -> Date = { Date() },
        refreshInterval: Duration = .seconds(AppConfig.expiryRefreshSeconds),
        loadFallback: Duration = .seconds(AppConfig.feedLoadFallbackSeconds)
    ) {
        self.service = service
        self.now = now
        self.refreshInterval = refreshInterval
        self.loadFallback = loadFallback
    }

    func post(id: String) -> FoodPost? {
        posts.first { $0.id == id }
    }

    // MARK: Lifecycle

    /// Listens until the calling task is cancelled. A second call while running does nothing, so there is never
    /// more than one listener.
    func run() async {
        guard !isRunning else { return }
        isRunning = true
        Logger.app.info("Posts repository started")
        defer {
            isRunning = false
            Logger.app.info("Posts repository stopped")
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.consumeSnapshots() }
            group.addTask { await self.tickExpiry() }
            group.addTask { await self.markLoadedAfterFallback() }
            await group.waitForAll()
        }
    }

    private func consumeSnapshots() async {
        for await posts in service.observeActivePosts() {
            apply(snapshot: posts)
        }
    }

    private func tickExpiry() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: refreshInterval)
            if Task.isCancelled { return }
            refresh()
        }
    }

    private func markLoadedAfterFallback() async {
        try? await Task.sleep(for: loadFallback)
        if !Task.isCancelled { hasLoaded = true }
    }

    // MARK: State

    func apply(snapshot newSnapshot: [FoodPost]) {
        snapshot = newSnapshot
        hasLoaded = true
        refresh()
    }

    /// Re-evaluates expiry against the clock. Called on every snapshot and every tick.
    func refresh() {
        let current = now()
        let next = snapshot
            .filter { $0.isActive(now: current) }
            .sorted { lhs, rhs in
                lhs.createdAt != rhs.createdAt ? lhs.createdAt > rhs.createdAt : lhs.id < rhs.id
            }
        if next != posts { posts = next }
    }
}
