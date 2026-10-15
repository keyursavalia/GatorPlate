import Foundation

nonisolated struct FoodPost: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var authorUid: String
    var authorName: String
    var orgName: String?

    var title: String
    var description: String

    var items: [FoodItem]
    var overallDietary: DietaryClass
    var allergenWarnings: [Allergen]
    var cautions: [String]
    var estimatedServings: Int?

    var buildingId: String
    var locationName: String
    /// e.g. "Room 201"
    var locationDetail: String?
    var latitude: Double
    var longitude: Double

    /// Uploaded photo slots, ascending (0 is the cover). See `PostPhotoSlots`.
    var photoSlots: [Int]
    var aiGenerated: Bool
    var editedAfterAI: Bool

    var status: PostStatus
    var createdAt: Date
    var expiresAt: Date
    var updatedAt: Date

    /// Never trust `status` alone: a post past `expiresAt` is over even if never marked.
    func isActive(now: Date = .now) -> Bool {
        status == .active && expiresAt > now
    }

    var hasPhoto: Bool { !photoSlots.isEmpty }

    /// The first uploaded slot: 0 unless the cover failed to upload.
    var coverSlot: Int? { photoSlots.first }

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}
