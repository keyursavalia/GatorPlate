import FirebaseFirestore
import Foundation

/// Explicit mapping between `FoodPost` and the `posts/{postId}` document, so the domain model stays free of
/// Firestore types. Field names and limits must match `firestore.rules`.
nonisolated enum FoodPostDocument {
    enum Key {
        static let authorUid = "authorUid"
        static let authorName = "authorName"
        static let orgName = "orgName"
        static let title = "title"
        static let description = "description"
        static let items = "items"
        static let overallDietary = "overallDietary"
        static let allergenWarnings = "allergenWarnings"
        static let cautions = "cautions"
        static let estimatedServings = "estimatedServings"
        static let buildingId = "buildingId"
        static let locationName = "locationName"
        static let locationDetail = "locationDetail"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let hasPhoto = "hasPhoto"
        /// Uploaded slots; `hasPhoto` is kept equal to `!photoSlots.isEmpty` for older readers.
        static let photoSlots = "photoSlots"
        static let aiGenerated = "aiGenerated"
        static let editedAfterAI = "editedAfterAI"
        static let status = "status"
        static let createdAt = "createdAt"
        static let expiresAt = "expiresAt"
        static let updatedAt = "updatedAt"
        /// TTL field: `expiresAt` plus `AppConfig.postRetentionHours`.
        static let deleteAt = "deleteAt"
    }

    // MARK: Writing

    /// Whole seconds, so `deleteAt == expiresAt + 24h` holds exactly in the rules.
    static func expiresAt(from now: Date, durationMinutes: Int) -> Timestamp {
        let seconds = (now.timeIntervalSince1970 + Double(durationMinutes * 60)).rounded()
        return Timestamp(seconds: Int64(seconds), nanoseconds: 0)
    }

    static func deleteAt(for expiresAt: Timestamp) -> Timestamp {
        Timestamp(seconds: expiresAt.seconds + Int64(AppConfig.postRetentionHours * 3600), nanoseconds: 0)
    }

    /// Create payload. `createdAt`/`updatedAt` are server timestamps; optional fields are omitted when nil.
    static func fields(for submission: PostSubmission, photoSlots: [Int], expiresAt: Timestamp) -> [String: Any] {
        var fields: [String: Any] = [
            Key.authorUid: submission.author.uid,
            Key.authorName: submission.author.displayName,
            Key.title: submission.title,
            Key.description: submission.description,
            Key.items: submission.items.map(itemFields),
            Key.overallDietary: submission.overallDietary.rawValue,
            Key.allergenWarnings: submission.allergens.map(\.rawValue),
            Key.cautions: submission.cautions,
            Key.buildingId: submission.location.building.id,
            Key.locationName: submission.location.displayName,
            Key.locationDetail: submission.locationDetail,
            Key.latitude: submission.location.coordinate.latitude,
            Key.longitude: submission.location.coordinate.longitude,
            Key.hasPhoto: !photoSlots.isEmpty,
            Key.photoSlots: photoSlots,
            Key.aiGenerated: submission.aiGenerated,
            Key.editedAfterAI: submission.editedAfterAI,
            Key.status: PostStatus.active.rawValue,
            Key.createdAt: FieldValue.serverTimestamp(),
            Key.updatedAt: FieldValue.serverTimestamp(),
            Key.expiresAt: expiresAt,
            Key.deleteAt: deleteAt(for: expiresAt),
        ]
        if let orgName = submission.author.orgName { fields[Key.orgName] = orgName }
        if let servings = submission.estimatedServings { fields[Key.estimatedServings] = servings }
        return fields
    }

    private static func itemFields(_ item: FoodItem) -> [String: Any] {
        var fields: [String: Any] = ["name": item.name, "dietary": item.dietary.rawValue]
        if let calories = item.calories { fields["calories"] = ["low": calories.low, "high": calories.high] }
        return fields
    }

    // MARK: Reading

    /// Nil when required fields are missing or malformed; such documents are skipped, never shown half-read.
    static func post(id: String, data: [String: Any]) -> FoodPost? {
        guard let authorUid = data[Key.authorUid] as? String,
              let authorName = data[Key.authorName] as? String,
              let title = data[Key.title] as? String,
              let description = data[Key.description] as? String,
              let buildingId = data[Key.buildingId] as? String,
              let locationName = data[Key.locationName] as? String,
              let latitude = data[Key.latitude] as? Double,
              let longitude = data[Key.longitude] as? Double,
              let status = (data[Key.status] as? String).flatMap(PostStatus.init(rawValue:)),
              let expiresAt = (data[Key.expiresAt] as? Timestamp)?.dateValue() else { return nil }
        // Server timestamps read as nil until the write is confirmed.
        let createdAt = (data[Key.createdAt] as? Timestamp)?.dateValue() ?? .now
        let items = (data[Key.items] as? [[String: Any]] ?? []).compactMap(item)
        return FoodPost(
            id: id, authorUid: authorUid, authorName: authorName, orgName: data[Key.orgName] as? String,
            title: title, description: description,
            items: items,
            overallDietary: (data[Key.overallDietary] as? String).flatMap(DietaryClass.init(rawValue:)) ?? .unknown,
            allergenWarnings: (data[Key.allergenWarnings] as? [String] ?? []).compactMap(Allergen.init(rawValue:)),
            cautions: data[Key.cautions] as? [String] ?? [],
            estimatedServings: data[Key.estimatedServings] as? Int,
            buildingId: buildingId, locationName: locationName,
            locationDetail: data[Key.locationDetail] as? String,
            latitude: latitude, longitude: longitude,
            photoSlots: PostPhotoSlots.decode(data[Key.photoSlots], hasPhoto: data[Key.hasPhoto] as? Bool),
            aiGenerated: data[Key.aiGenerated] as? Bool ?? false,
            editedAfterAI: data[Key.editedAfterAI] as? Bool ?? false,
            status: status, createdAt: createdAt, expiresAt: expiresAt,
            updatedAt: (data[Key.updatedAt] as? Timestamp)?.dateValue() ?? createdAt)
    }

    private static func item(_ fields: [String: Any]) -> FoodItem? {
        guard let name = fields["name"] as? String else { return nil }
        let dietary = (fields["dietary"] as? String).flatMap(DietaryClass.init(rawValue:)) ?? .unknown
        var calories: CalorieRange?
        if let range = fields["calories"] as? [String: Any], let low = range["low"] as? Int, let high = range["high"] as? Int {
            calories = CalorieRange(low: low, high: high)
        }
        return FoodItem(name: name, dietary: dietary, calories: calories)
    }
}
