import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

/// Live posts in Firestore `posts/{postId}`, photos through `ImageStore`, reports in `reports/{reportId}`.
@MainActor
final class FirestorePostService: PostService {
    private let images: any ImageStore

    init(images: any ImageStore) {
        self.images = images
    }

    private var posts: CollectionReference { Firestore.firestore().collection("posts") }
    private var reports: CollectionReference { Firestore.firestore().collection("reports") }

    // MARK: PostService

    /// Posts not yet expired as of subscription time, filtered client-side for `isActive`.
    func observeActivePosts() -> AsyncThrowingStream<PostsSnapshot, Error> {
        let query = posts
            .whereField(FoodPostDocument.Key.expiresAt, isGreaterThan: Timestamp(date: .now))
            .order(by: FoodPostDocument.Key.expiresAt)
        return AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: FirebaseErrorMapper.map(error))
                    return
                }
                let now = Date.now
                let posts = (snapshot?.documents ?? [])
                    .compactMap { FoodPostDocument.post(id: $0.documentID, data: $0.data()) }
                    .filter { $0.isActive(now: now) }
                continuation.yield(PostsSnapshot(posts: posts, isFromCache: snapshot?.metadata.isFromCache ?? false))
            }
            let listener = ListenerHandle(registration)
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func makePostId() -> String {
        posts.document().documentID
    }

    func publish(_ submission: PostSubmission, imageJPEG: Data?) async throws -> FoodPost {
        guard let uid = Auth.auth().currentUser?.uid, uid == submission.author.uid else { throw AppError.unauthorized }

        var hasPhoto = false
        if let imageJPEG {
            do {
                try await images.save(jpeg: imageJPEG, forPostId: submission.postId)
                hasPhoto = true
            } catch {
                // Never block the post on the photo.
                Logger.services.error("Photo upload failed; publishing without photo")
            }
        }

        let now = Date.now
        let expiresAt = FoodPostDocument.expiresAt(from: now, durationMinutes: submission.durationMinutes)
        let fields = FoodPostDocument.fields(for: submission, hasPhoto: hasPhoto, expiresAt: expiresAt)
        let document = posts.document(submission.postId)
        let start = ContinuousClock.now
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.postPublishTimeoutSeconds) { completion in
                document.setData(fields) { error in completion(error) }
            }
        } catch is DeadlineExceeded {
            Logger.services.error("Publish not confirmed before the deadline")
            throw AppError.network
        } catch {
            let appError = FirebaseErrorMapper.map(error)
            // A retry after a write that did land is denied (it would be an update); treat it as published.
            guard appError == .permissionDenied, await isPublished(document, by: uid) else {
                let nsError = error as NSError
                Logger.services.error("Publish failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
                throw appError
            }
        }
        Logger.services.info("Post published in \((ContinuousClock.now - start).formatted(.units(allowed: [.milliseconds])), privacy: .public), photo: \(hasPhoto, privacy: .public)")
        return FoodPost(submission: submission, hasPhoto: hasPhoto, createdAt: now, expiresAt: expiresAt.dateValue())
    }

    func markGone(postId: String) async throws {
        let document = posts.document(postId)
        do {
            // Completion handler with a deadline: the async overload waits for the server indefinitely offline.
            try await awaitCompletion(deadlineSeconds: AppConfig.postMarkGoneTimeoutSeconds) { completion in
                document.updateData([
                    FoodPostDocument.Key.status: PostStatus.gone.rawValue,
                    FoodPostDocument.Key.updatedAt: FieldValue.serverTimestamp(),
                ]) { error in completion(error) }
            }
        } catch is DeadlineExceeded {
            Logger.services.error("Mark as gone not confirmed before the deadline")
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    func report(postId: String, reason: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        let cleaned = PostText.limited(PostText.clean(reason), to: AppConfig.postReportReasonMaxLength)
        guard !cleaned.isEmpty else { throw AppError.validation("Add a reason for the report.") }
        do {
            _ = try await reports.addDocument(data: [
                "postId": postId,
                "reporterUid": uid,
                "reason": cleaned,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    // MARK: Helpers

    private func isPublished(_ document: DocumentReference, by uid: String) async -> Bool {
        guard let snapshot = try? await document.getDocument(source: .server), snapshot.exists else { return false }
        return snapshot.get(FoodPostDocument.Key.authorUid) as? String == uid
    }
}

/// `ListenerRegistration.remove()` is thread-safe, so the handle can be removed from the stream's termination handler.
private nonisolated final class ListenerHandle: @unchecked Sendable {
    private let registration: any ListenerRegistration

    init(_ registration: any ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}
