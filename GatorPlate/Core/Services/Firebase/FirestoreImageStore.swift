import FirebaseFirestore
import Foundation
import OSLog

/// Stores photos as `postImages/{postId}` documents. Used instead of Cloud Storage (see `docs/PROGRESS.md`);
/// swapping to Storage later is a change to this one file. Enforces the 300 KB cap before any write.
nonisolated struct FirestoreImageStore: ImageStore {
    private static let collection = "postImages"

    func save(jpeg: Data, forPostID postID: String) async throws {
        guard jpeg.count <= AppConfig.maxImageBytes else {
            throw AppError.validation("That photo is too large to post.")
        }
        guard !ImageMetadata.hasGPS(jpeg) else {
            throw AppError.validation("That photo still has location data, so it was not posted.")
        }
        var data: [String: Any] = ["jpeg": jpeg, "createdAt": Date()]
        if let size = ImageMetadata.pixelSize(of: jpeg) {
            data["width"] = Int(size.width)
            data["height"] = Int(size.height)
        }
        // Retention: the same `deleteAt` TTL field the post carries.
        data[FoodPostCoding.deleteAtKey] = Date().addingTimeInterval(
            TimeInterval(AppConfig.maxPostDurationMinutes * 60 + AppConfig.postRetentionSeconds)
        )
        let reference = Firestore.firestore().collection(Self.collection).document(postID)
        try await FirestoreWrite.set(reference, data: data, timeout: .seconds(AppConfig.publishTimeoutSeconds))
    }

    func load(forPostID postID: String) async throws -> Data? {
        do {
            let snapshot = try await Firestore.firestore().collection(Self.collection).document(postID).getDocument()
            return snapshot.data()?["jpeg"] as? Data
        } catch {
            Logger.firebase.error("Photo load failed")
            throw FirestoreErrorMapping.map(error)
        }
    }
}
