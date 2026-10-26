import Foundation

/// Post photos, one object per slot (0 = cover at `postImages/{postId}.jpg`, 1-3 at `{postId}_{slot}.jpg`).
/// Implementations reject JPEGs over `AppConfig.postImageMaxBytes` before writing.
@MainActor
protocol ImageStore: Sendable {
    func save(jpeg: Data, forPostId postId: String, slot: Int) async throws
    func load(forPostId postId: String, slot: Int) async throws -> Data?
}
