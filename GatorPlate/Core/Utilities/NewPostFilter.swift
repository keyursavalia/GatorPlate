import Foundation

/// Decides which posts deserve an alert. Pure state machine: feed it each posts snapshot.
///
/// A post is new for me when it is not mine, was created after this session started, is still active, and has not
/// been alerted before. The first loaded snapshot only seeds the "already seen" set, so posts that were up before
/// launch (or whose author's clock is ahead of mine) never alert.
nonisolated struct NewPostFilter: Sendable {
    let currentUserID: String
    let sessionStart: Date
    private(set) var notifiedIDs: Set<String> = []
    private(set) var isSeeded = false

    init(currentUserID: String, sessionStart: Date = Date()) {
        self.currentUserID = currentUserID
        self.sessionStart = sessionStart
    }

    /// Records the posts already on screen without alerting. Only the first call has an effect.
    mutating func seed(with posts: [FoodPost]) {
        guard !isSeeded else { return }
        isSeeded = true
        notifiedIDs.formUnion(posts.map(\.id))
    }

    /// Posts to alert for, oldest first. Each post id is returned at most once.
    mutating func newPosts(in posts: [FoodPost], now: Date = Date()) -> [FoodPost] {
        guard isSeeded else { return [] }
        let fresh = posts
            .filter { post in
                post.authorUid != currentUserID
                    && post.createdAt > sessionStart
                    && post.isActive(now: now)
                    && !notifiedIDs.contains(post.id)
            }
            .sorted { $0.createdAt < $1.createdAt }
        notifiedIDs.formUnion(fresh.map(\.id))
        return fresh
    }
}

nonisolated enum AlertContentFormatter {
    static let titlePrefix = "Free food"
    static let maxTitleLength = 80

    /// Banner and local notification text: "Free food: <title>" with the building as the body.
    static func content(for post: FoodPost) -> AlertContent {
        let title = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = title.count > maxTitleLength ? String(title.prefix(maxTitleLength - 1)) + "…" : title
        return AlertContent(
            postID: post.id,
            title: "\(titlePrefix): \(clipped.isEmpty ? "new post" : clipped)",
            body: post.locationName
        )
    }

    /// One-line banner message: "Free food: <title>, <building>".
    static func bannerMessage(for content: AlertContent) -> String {
        content.body.isEmpty ? content.title : "\(content.title), \(content.body)"
    }
}
