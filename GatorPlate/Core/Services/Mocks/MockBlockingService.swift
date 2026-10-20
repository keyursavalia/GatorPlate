import Foundation

/// In-memory blocks for previews and the harness.
@MainActor
final class MockBlockingService: BlockingService {
    private(set) var blocks: [BlockedUser]
    var error: AppError?
    private var continuations: [UUID: AsyncThrowingStream<[BlockedUser], Error>.Continuation] = [:]

    init(blocks: [BlockedUser] = []) {
        self.blocks = blocks
    }

    func observeBlocks() -> AsyncThrowingStream<[BlockedUser], Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(blocks)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    func block(uid: String, name: String, postId: String?) async throws {
        if let error { throw error }
        blocks.removeAll { $0.uid == uid }
        blocks.insert(BlockedUser(uid: uid, name: name, blockedAt: .now), at: 0)
        publish()
    }

    func unblock(uid: String) async throws {
        if let error { throw error }
        blocks.removeAll { $0.uid == uid }
        publish()
    }

    private func publish() {
        for continuation in continuations.values { continuation.yield(blocks) }
    }
}
