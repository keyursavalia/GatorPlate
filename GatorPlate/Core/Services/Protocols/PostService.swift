import Foundation

nonisolated protocol PostService: Sendable {
    /// Streams the active feed. Callers cancel the consuming task when the view disappears.
    func observeActivePosts() -> AsyncStream<[FoodPost]>
    func publish(_ post: FoodPost) async throws
    func markGone(postID: String) async throws
}
