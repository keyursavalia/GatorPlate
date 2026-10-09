import Foundation
import Observation

/// Tab and post selection for the signed-in UI. `selectPost(id:)` is the entry point for "View on map",
/// the feed, and tapped free food alerts.
@MainActor
@Observable
final class AppNavigation {
    enum TabID: Hashable {
        case map, feed, settings
    }

    static let postEndedNotice = "That food post has ended."
    static let alertPostUnavailableNotice = "That food is no longer available."

    var selectedTab = TabID.map
    var selectedPostId: String?
    /// Shown on the map when an opened or selected post is no longer active.
    private(set) var notice: String?

    @ObservationIgnored private let posts: PostsRepository
    @ObservationIgnored private let pendingWait: Duration
    @ObservationIgnored private var pendingPostId: String?
    @ObservationIgnored private var pendingNotice = AppNavigation.postEndedNotice
    @ObservationIgnored private var pendingTask: Task<Void, Never>?
    /// Posts this user is removing (Mark as gone): they close without the "ended" notice.
    @ObservationIgnored private var expectedRemovals: Set<String> = []

    init(posts: PostsRepository, pendingWait: Duration = .seconds(AppConfig.postSelectionPendingSeconds)) {
        self.posts = posts
        self.pendingWait = pendingWait
    }

    /// Opens the post on the map. A post that hasn't arrived yet waits until posts have loaded plus a short
    /// grace, then shows `missingNotice`.
    func selectPost(id: String, missingNotice: String = AppNavigation.postEndedNotice) {
        selectedTab = .map
        cancelPending()
        if posts.post(id: id) != nil {
            selectedPostId = id
            return
        }
        selectedPostId = nil
        pendingPostId = id
        pendingNotice = missingNotice
        startPendingTimerIfLoaded()
    }

    /// Call on every change to the active posts or the load phase.
    func postsDidChange() {
        if let pendingPostId {
            if posts.post(id: pendingPostId) != nil {
                cancelPending()
                selectedPostId = pendingPostId
            } else {
                startPendingTimerIfLoaded()
            }
        }
        if let selectedPostId, posts.post(id: selectedPostId) == nil {
            self.selectedPostId = nil
            if expectedRemovals.remove(selectedPostId) == nil { notice = Self.postEndedNotice }
        }
    }

    /// The user is marking this post as gone; when it leaves the feed, don't call it "ended".
    func expectRemoval(of postId: String) {
        expectedRemovals.insert(postId)
    }

    func cancelExpectedRemoval(of postId: String) {
        expectedRemovals.remove(postId)
    }

    func dismissNotice() {
        notice = nil
    }

    /// The wait starts only once posts have loaded, so a cold launch from an alert isn't mistaken for "ended".
    private func startPendingTimerIfLoaded() {
        guard let id = pendingPostId, pendingTask == nil, posts.phase == .loaded else { return }
        let wait = pendingWait
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, self.pendingPostId == id else { return }
            self.pendingPostId = nil
            self.pendingTask = nil
            self.notice = self.pendingNotice
        }
    }

    private func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingPostId = nil
    }
}
