import FirebaseAuth
import FirebaseStorage
import Foundation
import OSLog

/// Post photos in Cloud Storage at `postImages/{postId}.jpg`. `storage.rules` allows one create per object
/// (no overwrite), JPEG only, up to `postImageMaxBytes`, with `authorUid` metadata matching the uploader.
/// A bucket lifecycle rule deletes objects after the retention window.
@MainActor
final class FirebaseStorageImageStore: ImageStore {
    private static let contentType = "image/jpeg"

    private var storage: Storage {
        let storage = Storage.storage()
        // The default retries uploads for 10 minutes; a post can't wait that long.
        storage.maxUploadRetryTime = TimeInterval(AppConfig.postImageUploadTimeoutSeconds)
        return storage
    }

    func save(jpeg: Data, forPostId postId: String) async throws {
        guard jpeg.count <= AppConfig.postImageMaxBytes else {
            Logger.services.error("Post image over the cap; not uploaded")
            throw AppError.validation("Photo is too large.")
        }
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        let metadata = StorageMetadata()
        metadata.contentType = Self.contentType
        metadata.customMetadata = ["authorUid": uid]
        let reference = reference(for: postId)
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.postImageUploadTimeoutSeconds) { completion in
                reference.putData(jpeg, metadata: metadata) { _, error in completion(error) }
            }
        } catch {
            let appError = Self.map(error)
            // A retry after an upload that did land is denied (no overwrites); the photo is already there.
            if appError == .permissionDenied, await isUploaded(reference, by: uid) { return }
            throw appError
        }
    }

    func load(forPostId postId: String) async throws -> Data? {
        let reference = reference(for: postId)
        do {
            // Completion-handler API: the async overloads send the non-Sendable reference off the main actor.
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                reference.getData(maxSize: Int64(AppConfig.postImageMaxBytes)) { result in
                    continuation.resume(with: result)
                }
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain, nsError.code == StorageErrorCode.objectNotFound.rawValue { return nil }
            throw Self.map(error)
        }
    }

    private func isUploaded(_ reference: StorageReference, by uid: String) async -> Bool {
        let owner: String? = await withCheckedContinuation { continuation in
            reference.getMetadata { metadata, _ in
                continuation.resume(returning: metadata?.customMetadata?["authorUid"])
            }
        }
        return owner == uid
    }

    private func reference(for postId: String) -> StorageReference {
        storage.reference(withPath: "postImages/\(postId).jpg")
    }

    private static func map(_ error: Error) -> AppError {
        if error is DeadlineExceeded { return .network }
        let nsError = error as NSError
        Logger.services.error("Storage error: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
        guard nsError.domain == StorageErrorDomain, let code = StorageErrorCode(rawValue: nsError.code) else {
            return FirebaseErrorMapper.map(error)
        }
        switch code {
        case .unauthenticated, .unauthorized: return .permissionDenied
        case .retryLimitExceeded: return .network
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}
