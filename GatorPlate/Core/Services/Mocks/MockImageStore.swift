import Foundation

@MainActor
final class MockImageStore: ImageStore {
    private var storage: [String: Data] = [:]

    func save(jpeg: Data, forPostId postId: String) async throws {
        guard jpeg.count <= AppConfig.postImageMaxBytes else { throw AppError.validation("Photo is too large.") }
        storage[postId] = jpeg
    }

    func load(forPostId postId: String) async throws -> Data? { storage[postId] }
}
