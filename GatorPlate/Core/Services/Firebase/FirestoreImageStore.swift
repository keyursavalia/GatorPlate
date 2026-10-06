import Foundation
import OSLog

/// Live image store (Firestore `postImages` fallback). Stub until Sprint 05.
@MainActor
final class FirestoreImageStore: ImageStore {
    func save(jpeg: Data, forPostId postId: String) async throws {
        Logger.services.notice("FirestoreImageStore.save not implemented")
        throw AppError.unknown
    }

    func load(forPostId postId: String) async throws -> Data? {
        throw AppError.unknown
    }
}
