import Foundation
import Observation

/// Tab and post selection for the signed-in UI. `selectPost(id:)` is the entry point for "View on map",
/// the feed, and (Sprint 07) notifications.
@MainActor
@Observable
final class AppNavigation {
    enum TabID: Hashable {
        case map, feed, settings
    }

    var selectedTab = TabID.map
    var selectedPostId: String?
    /// Shown on the map when an opened or selected post is no longer active.
    private(set) var showsPostEndedNotice = false

    @ObservationIgnored private let posts: PostsRepository
    @ObservationIgnored private let pendingWait: Duration
    @ObservationIgnored private var pendingPostId: String?
    @ObservationIgnored private var pendingTask: Task<Void, Never>?
    /// Posts this user is removing (Mark as gone): they close without the "ended" notice.
    @ObservationIgnored private var expectedRemovals: Set<String> = []

    init(posts: PostsRepository, pendingWait: Duration = .seconds(AppConfig.postSelectionPendingSeconds)) {
        self.posts = posts
        self.pendingWait = pendingWait
    }

    /// Opens the post on the map. A post that hasn't arrived yet waits briefly, then counts as ended.
    func selectPost(id: String) {
        selectedTab = .map
        cancelPending()
        if posts.post(id: id) != nil {
            selectedPostId = id
            return
        }
        selectedPostId = nil
        pendingPostId = id
        let wait = pendingWait
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, self.pendingPostId == id else { return }
            self.pendingPostId = nil
            self.showsPostEndedNotice = true
        }
    }

    /// Call on every change to the active posts.
    func postsDidChange() {
        if let pendingPostId, posts.post(id: pendingPostId) != nil {
            cancelPending()
            selectedPostId = pendingPostId
        }
        if let selectedPostId, posts.post(id: selectedPostId) == nil {
            self.selectedPostId = nil
            if expectedRemovals.remove(selectedPostId) == nil { showsPostEndedNotice = true }
        }
    }

    /// The user is marking this post as gone; when it leaves the feed, don't call it "ended".
    func expectRemoval(of postId: String) {
        expectedRemovals.insert(postId)
    }

    func cancelExpectedRemoval(of postId: String) {
        expectedRemovals.remove(postId)
    }

    func dismissPostEndedNotice() {
        showsPostEndedNotice = false
    }

    private func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingPostId = nil
    }
}
