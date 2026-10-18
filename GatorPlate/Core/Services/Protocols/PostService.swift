import Foundation

@MainActor
protocol PostService {
    /// Emits the current set of posts on every change, cache first, then server. Cancel the consuming task
    /// to unsubscribe.
    func observeActivePosts() -> AsyncThrowingStream<PostsSnapshot, Error>
    /// A new post ID. Create it once per draft and reuse it when retrying, so a retry never duplicates a post.
    func makePostId() -> String
    /// Uploads the photos in parallel (index = slot; nil = couldn't be encoded), then writes the post with the
    /// slots that uploaded. A failed photo never blocks publishing: its slot is left out of `photoSlots`.
    func publish(_ submission: PostSubmission, photos: [Data?]) async throws -> PublishResult
    func markGone(postId: String) async throws
    func report(postId: String, reason: String) async throws
}

extension PostService {
    /// Firestore-style ID: 20 alphanumeric characters (also what `storage.rules` accepts).
    static func randomPostId() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<20).compactMap { _ in alphabet.randomElement() })
    }
}

/// The published post plus how many of the chosen photos made it (the success screen says "2 of 3 photos").
nonisolated struct PublishResult: Equatable, Sendable {
    var post: FoodPost
    var requestedPhotos: Int

    var uploadedPhotos: Int { post.photoSlots.count }
    var hasPhotoFailures: Bool { uploadedPhotos < requestedPhotos }
}

nonisolated extension FoodPost {
    /// The post as written for a submission. Server timestamps replace the dates in Firestore.
    init(submission: PostSubmission, photoSlots: [Int], createdAt: Date, expiresAt: Date) {
        self.init(
            id: submission.postId,
            authorUid: submission.author.uid, authorName: submission.author.displayName,
            orgName: submission.author.orgName,
            title: submission.title, description: submission.description,
            items: submission.items, overallDietary: submission.overallDietary,
            allergenWarnings: submission.allergens, cautions: submission.cautions,
            estimatedServings: submission.estimatedServings,
            buildingId: submission.location.building.id, locationName: submission.location.displayName,
            locationDetail: submission.locationDetail,
            latitude: submission.location.coordinate.latitude, longitude: submission.location.coordinate.longitude,
            photoSlots: photoSlots, aiGenerated: submission.aiGenerated, editedAfterAI: submission.editedAfterAI,
            status: .active, createdAt: createdAt, expiresAt: expiresAt, updatedAt: createdAt)
    }
}
