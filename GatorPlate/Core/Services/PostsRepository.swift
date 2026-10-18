import Foundation
import Observation
import OSLog

/// The one live posts listener for a signed-in session, shared by the map and the feed.
/// Start it when the main UI appears and stop it before sign-out. Expiry runs on a timer, no server needed.
@MainActor
@Observable
final class PostsRepository {
    enum Phase: Equatable {
        /// No usable snapshot yet (an empty cache snapshot still counts as loading).
        case loading
        case loaded
    }

    /// Active posts, newest first. Reassigned only when the set or a post actually changes.
    private(set) var activePosts: [FoodPost] = []
    private(set) var phase = Phase.loading
    /// True after the listener failed; the last posts stay visible while it retries.
    private(set) var hasError = false
    /// Snapshots from the server so far. A post opened from an alert counts as missing only after a server
    /// result that came in after the tap (a resumed app may still be reconnecting).
    private(set) var serverSnapshotCount = 0

    @ObservationIgnored private let service: any PostService
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let tickInterval: Duration
    @ObservationIgnored private let cacheGrace: Duration
    @ObservationIgnored private var allPosts: [FoodPost] = []
    @ObservationIgnored private var subscription: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var graceTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundedAt: Date?
    /// Set on every (re)subscribe until the first server snapshot arrives.
    @ObservationIgnored private var awaitingServer = true

    init(service: any PostService,
         now: @escaping () -> Date = { .now },
         tickInterval: Duration = .seconds(AppConfig.postsExpiryTickSeconds),
         cacheGrace: Duration = .seconds(AppConfig.postsCacheGraceSeconds)) {
        self.service = service
        self.now = now
        self.tickInterval = tickInterval
        self.cacheGrace = cacheGrace
    }

    var isRunning: Bool { subscription != nil }

    func post(id: String) -> FoodPost? {
        activePosts.first { $0.id == id }
    }

    // MARK: Lifecycle

    /// Idempotent.
    func start() {
        guard subscription == nil else { return }
        subscribe()
        startTicker()
        Logger.services.info("Posts listener started")
    }

    /// Removes the listener. Call before signing out: rules deny reads once the user is gone.
    func stop() {
        guard subscription != nil else { return }
        subscription?.cancel()
        subscription = nil
        ticker?.cancel()
        ticker = nil
        graceTask?.cancel()
        graceTask = nil
        backgroundedAt = nil
        Logger.services.info("Posts listener stopped")
    }

    func didEnterBackground() {
        guard isRunning else { return }
        backgroundedAt = now()
    }

    /// Re-checks expiry at once; after a long background, restarts the listener so its query bound is fresh.
    func didBecomeActive() {
        guard isRunning else { return }
        defer { backgroundedAt = nil }
        if let backgroundedAt,
           now().timeIntervalSince(backgroundedAt) >= Double(AppConfig.postsResubscribeAfterBackgroundSeconds) {
            subscribe()
        }
        refresh()
    }

    /// Re-evaluates `isActive`; expired posts drop out.
    func refresh() {
        let next = ActivePosts.filter(allPosts, now: now())
        if next != activePosts { activePosts = next }
    }

    // MARK: Listener

    /// Applies one snapshot. Internal so tests can drive it directly.
    func receive(_ snapshot: PostsSnapshot) {
        if hasError { hasError = false }
        // Cache first, server second: an empty cache must not flash the empty state or wipe current posts.
        if awaitingServer, snapshot.isFromCache, snapshot.posts.isEmpty {
            if phase == .loading { scheduleCacheGrace() }
            return
        }
        if !snapshot.isFromCache {
            awaitingServer = false
            serverSnapshotCount += 1
        }
        allPosts = snapshot.posts
        graceTask?.cancel()
        graceTask = nil
        refresh()
        if phase != .loaded { phase = .loaded }
    }

    private func subscribe() {
        subscription?.cancel()
        awaitingServer = true
        let service = service
        subscription = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                do {
                    for try await snapshot in service.observeActivePosts() {
                        attempt = 0
                        self?.receive(snapshot)
                    }
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    attempt += 1
                    let delay = Self.retryDelaySeconds(attempt: attempt)
                    Logger.services.error("Posts listener failed, retry \(attempt, privacy: .public) in \(delay, privacy: .public)s: \(String(describing: error), privacy: .public)")
                    self?.hasError = true
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
    }

    /// 2, 4, 8, 16, then the cap.
    nonisolated static func retryDelaySeconds(attempt: Int) -> Int {
        let exponent = min(max(attempt, 1), 5)
        return min(1 << exponent, AppConfig.postsRetryMaxDelaySeconds)
    }

    private func startTicker() {
        ticker?.cancel()
        let interval = tickInterval
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    private func scheduleCacheGrace() {
        guard graceTask == nil else { return }
        let grace = cacheGrace
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: grace)
            guard !Task.isCancelled, let self, self.phase == .loading else { return }
            self.graceTask = nil
            self.refresh()
            self.phase = .loaded
        }
    }
}
