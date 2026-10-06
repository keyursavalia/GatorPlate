import Foundation

@MainActor
protocol PostService {
    /// Emits the current set of posts on every change. Cancel the consuming task to unsubscribe.
    func observeActivePosts() -> AsyncThrowingStream<[FoodPost], Error>
    func createPost(_ post: FoodPost) async throws
    func markGone(postId: String) async throws
    func report(postId: String, reason: String) async throws
}
