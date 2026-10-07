import Foundation

/// Post photos. Implementations reject JPEGs over `AppConfig.postImageMaxBytes` before writing.
@MainActor
protocol ImageStore {
    func save(jpeg: Data, forPostId postId: String) async throws
    func load(forPostId postId: String) async throws -> Data?
}
