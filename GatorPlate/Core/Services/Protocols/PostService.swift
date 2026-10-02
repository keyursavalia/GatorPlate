import Foundation

nonisolated protocol PostService: Sendable {
    /// Streams the active feed. Callers cancel the consuming task when the view disappears.
    func observeActivePosts() -> AsyncStream<[FoodPost]>

    /// Stores the photo (when given and it fits the size cap), then the post. A photo that cannot be stored never
    /// blocks the post: the returned post then has `hasPhoto == false`. Publishing the same post id twice
    /// overwrites, so a retry after a failure is safe.
    func publish(_ post: FoodPost, imageJPEG: Data?) async throws -> FoodPost

    func markGone(postID: String) async throws
    func report(postID: String, reason: String) async throws
}
