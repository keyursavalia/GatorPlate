import Foundation

@MainActor
final class MockImageStore: ImageStore {
    private var storage: [String: Data] = [:]

    func save(jpeg: Data, forPostId postId: String) async throws { storage[postId] = jpeg }

    func load(forPostId postId: String) async throws -> Data? { storage[postId] }
}
