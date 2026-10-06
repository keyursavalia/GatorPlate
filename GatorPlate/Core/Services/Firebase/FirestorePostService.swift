import Foundation
import OSLog

/// Live post storage. Stub until Sprint 05/06.
@MainActor
final class FirestorePostService: PostService {
    func observeActivePosts() -> AsyncThrowingStream<[FoodPost], Error> {
        AsyncThrowingStream { $0.finish(throwing: AppError.unknown) }
    }

    func createPost(_ post: FoodPost) async throws {
        Logger.services.notice("FirestorePostService.createPost not implemented")
        throw AppError.unknown
    }

    func markGone(postId: String) async throws { throw AppError.unknown }

    func report(postId: String, reason: String) async throws { throw AppError.unknown }
}
