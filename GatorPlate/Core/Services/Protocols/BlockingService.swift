import Foundation

/// Blocking posters (`blocks` collection). Guests can block too (they have an anonymous uid).
@MainActor
protocol BlockingService {
    /// The signed-in user's blocks (`where blockerUid == me`), newest first, live.
    func observeBlocks() -> AsyncThrowingStream<[BlockedUser], Error>
    func block(uid: String, name: String, postId: String?) async throws
    func unblock(uid: String) async throws
}
