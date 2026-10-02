import FirebaseAuth
@preconcurrency import FirebaseFirestore
import Foundation
import OSLog

/// Firestore `posts/{id}` and `reports/{id}` implementation. The photo goes through the injected `ImageStore`.
/// Never logs titles, descriptions or photos.
nonisolated struct FirestorePostService: PostService {
    private static let postsCollection = "posts"
    private static let reportsCollection = "reports"
    private static let maxReportReasonLength = 300

    /// Wraps the listener handle so a `@Sendable` termination closure can capture it (same pattern as the auth service).
    private nonisolated struct ListenerToken: @unchecked Sendable {
        let registration: any ListenerRegistration
    }

    private let images: any ImageStore

    init(images: any ImageStore) {
        self.images = images
    }

    private var timeout: Duration { .seconds(AppConfig.publishTimeoutSeconds) }

    // MARK: Publish

    func publish(_ post: FoodPost, imageJPEG: Data?) async throws -> FoodPost {
        var stored = post
        stored.hasPhoto = false
        if let imageJPEG {
            do {
                try await images.save(jpeg: imageJPEG, forPostID: post.id)
                stored.hasPhoto = true
            } catch AppError.network {
                // Offline: fail the whole publish so the poster can retry with the photo attached.
                throw AppError.network
            } catch {
                // Anything else (too large, rejected): the post still goes out without a photo.
                Logger.firebase.error("Photo not stored, publishing without it")
            }
        }

        let reference = Firestore.firestore().collection(Self.postsCollection).document(stored.id)
        do {
            try await FirestoreWrite.set(reference, data: FoodPostCoding.dictionary(from: stored), timeout: timeout)
        } catch {
            Logger.firebase.error("Publish failed")
            throw FirestoreErrorMapping.map(error)
        }
        return stored
    }

    // MARK: Mark as gone, report

    func markGone(postID: String) async throws {
        let reference = Firestore.firestore().collection(Self.postsCollection).document(postID)
        let fields: [AnyHashable: Any] = ["status": PostStatus.gone.rawValue, "updatedAt": Date()]
        do {
            try await FirestoreWrite.update(reference, fields: fields, timeout: timeout)
        } catch {
            Logger.firebase.error("Mark as gone failed")
            throw FirestoreErrorMapping.map(error)
        }
    }

    func report(postID: String, reason: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        let reference = Firestore.firestore().collection(Self.reportsCollection).document()
        let data: [String: Any] = [
            "postId": postID,
            "reporterUid": uid,
            "reason": String(PostText.line(reason).prefix(Self.maxReportReasonLength)),
            "createdAt": Date()
        ]
        do {
            try await FirestoreWrite.set(reference, data: data, timeout: timeout)
        } catch {
            Logger.firebase.error("Report failed")
            throw FirestoreErrorMapping.map(error)
        }
    }

    // MARK: Observe

    func observeActivePosts() -> AsyncStream<[FoodPost]> {
        AsyncStream { continuation in
            let query = Firestore.firestore().collection(Self.postsCollection)
                .whereField("expiresAt", isGreaterThan: Date())
                .order(by: "expiresAt")
            let listener = query.addSnapshotListener { snapshot, error in
                if error != nil {
                    Logger.firebase.error("Feed listener error")
                    return
                }
                guard let snapshot else { return }
                // An empty cache-only snapshot is not an answer yet: the server snapshot follows, and showing
                // "No free food" for a moment on a cold start would be wrong. (Offline, the repository's
                // fallback timer ends the loading state.)
                if snapshot.metadata.isFromCache && snapshot.documents.isEmpty { return }
                let posts = snapshot.documents
                    .compactMap { FoodPostCoding.post(from: Self.normalized($0.data())) }
                    .filter { $0.isActive() }
                continuation.yield(posts)
            }
            Logger.firebase.info("Active-posts listener started")
            let token = ListenerToken(registration: listener)
            continuation.onTermination = { _ in
                token.registration.remove()
                Logger.firebase.info("Active-posts listener stopped")
            }
        }
    }

    /// Firestore returns `Timestamp`; the coding helper works in `Date`.
    private static func normalized(_ data: [String: Any]) -> [String: Any] {
        data.mapValues { ($0 as? Timestamp)?.dateValue() ?? $0 }
    }
}
