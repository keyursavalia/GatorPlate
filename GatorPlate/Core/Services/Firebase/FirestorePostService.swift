import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog
import Synchronization

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

    func fetchPost(id: String) async throws -> FoodPost? {
        let document = posts.document(id)
        let found = FetchedPost()
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.alertLookupTimeoutSeconds) { completion in
                document.getDocument(source: .server) { snapshot, error in
                    if let snapshot, snapshot.exists, let data = snapshot.data() {
                        found.set(FoodPostDocument.post(id: snapshot.documentID, data: data))
                    }
                    completion(error)
                }
            }
        } catch is DeadlineExceeded {
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        return found.value
    }

    func makePostId() -> String {
        posts.document().documentID
    }

    func publish(_ submission: PostSubmission, photos: [Data?]) async throws -> PublishResult {
        guard let uid = Auth.auth().currentUser?.uid, uid == submission.author.uid else { throw AppError.unauthorized }

        let photoSlots = await uploadPhotos(photos, postId: submission.postId)
        let now = Date.now
        let expiresAt = FoodPostDocument.expiresAt(from: now, durationMinutes: submission.durationMinutes)
        let fields = FoodPostDocument.fields(for: submission, photoSlots: photoSlots, expiresAt: expiresAt)
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
        Logger.services.info("Post published in \((ContinuousClock.now - start).formatted(.units(allowed: [.milliseconds])), privacy: .public), photos: \(photoSlots.count, privacy: .public)/\(photos.count, privacy: .public)")
        let post = FoodPost(submission: submission, photoSlots: photoSlots, createdAt: now,
                            expiresAt: expiresAt.dateValue())
        return PublishResult(post: post, requestedPhotos: photos.count)
    }

    /// Parallel uploads, each with its own deadline (`ImageStore`). Returns the slots that made it, ascending.
    /// A retried publish reuses the post ID and slots; an object already uploaded counts as uploaded.
    private func uploadPhotos(_ photos: [Data?], postId: String) async -> [Int] {
        let images = images
        // Main-actor tasks run concurrently: each upload waits on its own network completion.
        let uploads: [Task<Int?, Never>] = photos.prefix(AppConfig.postMaxPhotos).enumerated().compactMap { slot, jpeg in
            guard let jpeg else { return nil }
            return Task {
                do {
                    try await images.save(jpeg: jpeg, forPostId: postId, slot: slot)
                    return slot
                } catch {
                    // Never block the post on a photo.
                    Logger.services.error("Photo upload failed for slot \(slot, privacy: .public)")
                    return nil
                }
            }
        }
        var uploaded: [Int] = []
        for upload in uploads {
            if let slot = await upload.value { uploaded.append(slot) }
        }
        return uploaded.sorted()
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

/// Carries `fetchPost`'s result out of the Firestore callback.
private nonisolated final class FetchedPost: Sendable {
    private let post = Mutex<FoodPost?>(nil)

    var value: FoodPost? { post.withLock { $0 } }

    func set(_ value: FoodPost?) {
        post.withLock { $0 = value }
    }
}
