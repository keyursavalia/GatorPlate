import Foundation

/// Explicit `FoodPost` <-> Firestore dictionary mapping. Dates stay `Date` here (the SDK stores them as
/// Timestamps); `FirestorePostService` converts Timestamps back to `Date` before decoding. No Firebase import,
/// so it is unit-testable.
nonisolated enum FoodPostCoding {
    /// Documents carry this extra field so a Firestore TTL policy can delete them after the retention window.
    static let deleteAtKey = "deleteAt"

    static func deleteAt(for post: FoodPost) -> Date {
        post.expiresAt.addingTimeInterval(TimeInterval(AppConfig.postRetentionSeconds))
    }

    static func dictionary(from post: FoodPost) -> [String: Any] {
        var data: [String: Any] = [
            "id": post.id,
            "authorUid": post.authorUid,
            "authorName": post.authorName,
            "title": post.title,
            "description": post.description,
            "items": post.items.map(itemDictionary),
            "overallDietary": post.overallDietary.rawValue,
            "allergenWarnings": post.allergenWarnings.map(\.rawValue),
            "cautions": post.cautions,
            "buildingId": post.buildingId,
            "locationName": post.locationName,
            "latitude": post.latitude,
            "longitude": post.longitude,
            "hasPhoto": post.hasPhoto,
            "aiGenerated": post.aiGenerated,
            "editedAfterAI": post.editedAfterAI,
            "status": post.status.rawValue,
            "createdAt": post.createdAt,
            "expiresAt": post.expiresAt,
            "updatedAt": post.updatedAt,
            deleteAtKey: deleteAt(for: post)
        ]
        if let orgName = post.orgName { data["orgName"] = orgName }
        if let servings = post.estimatedServings { data["estimatedServings"] = servings }
        if let detail = post.locationDetail { data["locationDetail"] = detail }
        return data
    }

    private static func itemDictionary(_ item: FoodItem) -> [String: Any] {
        var data: [String: Any] = ["name": item.name, "dietary": item.dietary.rawValue]
        if let calories = item.calories {
            data["calories"] = ["low": calories.low, "high": calories.high]
        }
        return data
    }

    /// Returns nil for a document that is missing required fields, so one bad document never breaks the feed.
    static func post(from data: [String: Any]) -> FoodPost? {
        guard let id = data["id"] as? String,
              let authorUid = data["authorUid"] as? String,
              let authorName = data["authorName"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let buildingId = data["buildingId"] as? String,
              let locationName = data["locationName"] as? String,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let status = (data["status"] as? String).flatMap(PostStatus.init(rawValue:)),
              let createdAt = data["createdAt"] as? Date,
              let expiresAt = data["expiresAt"] as? Date,
              let updatedAt = data["updatedAt"] as? Date
        else { return nil }

        let items = (data["items"] as? [[String: Any]] ?? []).compactMap(item(from:))
        let allergens = (data["allergenWarnings"] as? [String] ?? []).compactMap(Allergen.init(rawValue:))
        return FoodPost(
            id: id,
            authorUid: authorUid,
            authorName: authorName,
            orgName: data["orgName"] as? String,
            title: title,
            description: description,
            items: items,
            overallDietary: (data["overallDietary"] as? String).flatMap(DietaryClass.init(rawValue:)) ?? .unknown,
            allergenWarnings: allergens,
            cautions: data["cautions"] as? [String] ?? [],
            estimatedServings: data["estimatedServings"] as? Int,
            buildingId: buildingId,
            locationName: locationName,
            locationDetail: data["locationDetail"] as? String,
            latitude: latitude,
            longitude: longitude,
            hasPhoto: data["hasPhoto"] as? Bool ?? false,
            aiGenerated: data["aiGenerated"] as? Bool ?? false,
            editedAfterAI: data["editedAfterAI"] as? Bool ?? false,
            status: status,
            createdAt: createdAt,
            expiresAt: expiresAt,
            updatedAt: updatedAt
        )
    }

    private static func item(from data: [String: Any]) -> FoodItem? {
        guard let name = data["name"] as? String else { return nil }
        let calories = (data["calories"] as? [String: Any]).flatMap { raw -> CalorieRange? in
            guard let low = raw["low"] as? Int, let high = raw["high"] as? Int else { return nil }
            return CalorieRange(low: low, high: high)
        }
        return FoodItem(
            name: name,
            dietary: (data["dietary"] as? String).flatMap(DietaryClass.init(rawValue:)) ?? .unknown,
            calories: calories
        )
    }
}
