import Foundation

@MainActor
protocol ImageStore {
    func save(jpeg: Data, forPostId postId: String) async throws
    func load(forPostId postId: String) async throws -> Data?
}
