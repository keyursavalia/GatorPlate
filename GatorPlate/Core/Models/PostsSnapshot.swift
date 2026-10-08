import Foundation

/// One delivery from the posts listener. Firestore delivers the local cache first, then the server result.
nonisolated struct PostsSnapshot: Equatable, Sendable {
    var posts: [FoodPost]
    /// True while the data comes only from the local cache (an empty cache is not "no posts yet").
    var isFromCache: Bool
}
