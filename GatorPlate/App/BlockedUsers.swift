import Foundation
import Observation
import OSLog

/// The people this user blocked, for one session (started and stopped with `MainSession`). Map and Feed hide their
/// posts through `BrowseResults`; Settings > Safety lists them. Blocking and unblocking are optimistic: the change
/// shows at once and is undone if the write fails.
@MainActor
@Observable
final class BlockedUsers {
    enum BlockResult: Equatable {
        case blocked
        case limitReached
        case failed
    }

    static let failedMessage = "Couldn't block. Try again."
    static let unblockFailedMessage = "Couldn't unblock. Try again."
    static let limitMessage = "You've blocked the maximum number of people. Unblock someone first."

    /// Newest first.
    private(set) var users: [BlockedUser] = []
    private(set) var uids: Set<String> = []

    @ObservationIgnored private let service: any BlockingService
    @ObservationIgnored private let maxCount: Int
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    /// Optimistic changes not yet confirmed: they win over listener snapshots until the write finishes.
    @ObservationIgnored private var pendingBlocks: [String: BlockedUser] = [:]
    @ObservationIgnored private var pendingUnblocks: Set<String> = []
    @ObservationIgnored private var confirmed: [BlockedUser] = []

    init(service: any BlockingService, maxCount: Int = AppConfig.maxBlockedUsers) {
        self.service = service
        self.maxCount = maxCount
    }

    func contains(_ uid: String) -> Bool {
        uids.contains(uid)
    }

    /// Follows the server list; a failed listener retries with a short backoff.
    func start() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            var delay = 2
            while !Task.isCancelled {
                guard let stream = self?.service.observeBlocks() else { return }
                do {
                    for try await list in stream {
                        self?.confirmed = list
                        self?.apply()
                        delay = 2
                    }
                    return
                } catch {
                    Logger.services.error("Blocks listener failed; retrying")
                }
                try? await Task.sleep(for: .seconds(delay))
                delay = min(delay * 2, AppConfig.postsRetryMaxDelaySeconds)
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
    }

    func block(uid: String, name: String, postId: String?) async -> BlockResult {
        guard !contains(uid) else { return .blocked }
        guard users.count < maxCount else { return .limitReached }
        pendingBlocks[uid] = BlockedUser(uid: uid, name: name, blockedAt: .now)
        apply()
        do {
            try await service.block(uid: uid, name: name, postId: postId)
            if let pending = pendingBlocks.removeValue(forKey: uid), !confirmed.contains(where: { $0.uid == uid }) {
                confirmed.insert(pending, at: 0)
            }
            apply()
            Logger.ui.info("Poster blocked")
            return .blocked
        } catch {
            pendingBlocks[uid] = nil
            apply()
            Logger.services.error("Block failed")
            return .failed
        }
    }

    /// False when the write failed (the person stays blocked).
    func unblock(uid: String) async -> Bool {
        guard contains(uid) else { return true }
        pendingUnblocks.insert(uid)
        apply()
        do {
            try await service.unblock(uid: uid)
            pendingUnblocks.remove(uid)
            confirmed.removeAll { $0.uid == uid }
            apply()
            return true
        } catch {
            pendingUnblocks.remove(uid)
            apply()
            Logger.services.error("Unblock failed")
            return false
        }
    }

    private func apply() {
        var list = confirmed.filter { !pendingUnblocks.contains($0.uid) && pendingBlocks[$0.uid] == nil }
        list.append(contentsOf: pendingBlocks.values)
        list.sort { $0.blockedAt > $1.blockedAt }
        if list != users { users = list }
        let ids = Set(list.map(\.uid))
        if ids != uids { uids = ids }
    }
}
