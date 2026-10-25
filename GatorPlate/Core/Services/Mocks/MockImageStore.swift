import Foundation

#if DEBUG
@MainActor
final class MockImageStore: ImageStore {
    private var storage: [String: Data] = [:]
    /// Slots that fail to upload, to simulate partial failures.
    var failingSlots: Set<Int> = []

    func save(jpeg: Data, forPostId postId: String, slot: Int) async throws {
        guard jpeg.count <= AppConfig.postImageMaxBytes else { throw AppError.validation("Photo is too large.") }
        guard !failingSlots.contains(slot) else { throw AppError.network }
        storage[PostPhotoSlots.objectName(postId: postId, slot: slot)] = jpeg
    }

    func load(forPostId postId: String, slot: Int) async throws -> Data? {
        storage[PostPhotoSlots.objectName(postId: postId, slot: slot)]
    }
}
#endif
