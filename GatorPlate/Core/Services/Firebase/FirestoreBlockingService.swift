import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Blocks in Firestore `blocks/{blockerUid}_{blockedUid}`. The ID makes one block per pair; rules let only the
/// blocker create, read and delete it. The `onBlockCreated` function counts blocks per poster for admin review.
@MainActor
final class FirestoreBlockingService: BlockingService {
    private var blocks: CollectionReference { Firestore.firestore().collection("blocks") }

    func observeBlocks() -> AsyncThrowingStream<[BlockedUser], Error> {
        guard let uid = Auth.auth().currentUser?.uid else {
            return AsyncThrowingStream { $0.finish(throwing: AppError.unauthorized) }
        }
        // `where blockerUid == me` so the read rule can prove access.
        let query = blocks.whereField("blockerUid", isEqualTo: uid)
        return AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: FirebaseErrorMapper.map(error))
                    return
                }
                let users = (snapshot?.documents ?? []).compactMap { document -> BlockedUser? in
                    let data = document.data(with: .estimate)
                    guard let blockedUid = data["blockedUid"] as? String, !blockedUid.isEmpty else { return nil }
                    let name = data["blockedName"] as? String ?? ""
                    let blockedAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
                    return BlockedUser(uid: blockedUid, name: name, blockedAt: blockedAt)
                }
                continuation.yield(users.sorted { $0.blockedAt > $1.blockedAt })
            }
            let listener = BlockListenerHandle(registration)
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func block(uid blockedUid: String, name: String, postId: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        var data: [String: Any] = [
            "blockerUid": uid,
            "blockedUid": blockedUid,
            "blockedName": String(name.prefix(AppConfig.maxNameLength)),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let postId { data["postId"] = postId }
        let document = blocks.document("\(uid)_\(blockedUid)")
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.accountWriteTimeoutSeconds) { completion in
                document.setData(data) { completion($0) }
            }
        } catch is DeadlineExceeded {
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    func unblock(uid blockedUid: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        let document = blocks.document("\(uid)_\(blockedUid)")
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.accountWriteTimeoutSeconds) { completion in
                document.delete { completion($0) }
            }
        } catch is DeadlineExceeded {
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }
}

private nonisolated final class BlockListenerHandle: @unchecked Sendable {
    private let registration: any ListenerRegistration

    init(_ registration: any ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}
