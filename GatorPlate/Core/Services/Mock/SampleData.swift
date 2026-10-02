import Foundation

/// Sample data used by mock services, previews, and tests.
nonisolated enum SampleData {
    static let campusCoordinate = Coordinate(latitude: 37.7219, longitude: -122.4782)

    static let profile = UserProfile(
        uid: "mock-user",
        displayName: "Gator Student",
        email: "student@sfsu.edu",
        accountType: .student,
        orgName: nil,
        acceptedTermsVersion: AppConfig.termsVersion,
        acceptedTermsAt: Date(timeIntervalSince1970: 1_790_000_000),
        notificationsEnabled: true,
        createdAt: Date(timeIntervalSince1970: 1_790_000_000)
    )

    static func post(now: Date = Date(), id: String = "mock-post") -> FoodPost {
        FoodPost(
            id: id,
            authorUid: "mock-user",
            authorName: "Gator Student",
            orgName: "Sample Club",
            title: "Pad Thai",
            description: "Leftover vegetable pad thai from our meeting.",
            items: [
                FoodItem(name: "Pad Thai", dietary: .vegetarian, calories: CalorieRange(low: 420, high: 520))
            ],
            overallDietary: .vegetarian,
            allergenWarnings: [.soy, .peanuts],
            cautions: ["Double-check allergens with the host."],
            estimatedServings: 6,
            buildingId: "sample-building",
            locationName: "Sample Hall",
            locationDetail: "Room 201",
            latitude: campusCoordinate.latitude,
            longitude: campusCoordinate.longitude,
            hasPhoto: false,
            aiGenerated: false,
            editedAfterAI: false,
            status: .active,
            createdAt: now,
            expiresAt: now.addingTimeInterval(TimeInterval(AppConfig.defaultPostDurationMinutes * 60)),
            updatedAt: now
        )
    }

    static let analysis = FoodAnalysisResult(
        title: "Pad Thai",
        description: "Vegetable pad thai, served warm.",
        items: [FoodItem(name: "Pad Thai", dietary: .vegetarian, calories: CalorieRange(low: 420, high: 520))],
        overallDietary: .vegetarian,
        allergenWarnings: [.soy, .peanuts],
        cautions: [],
        estimatedServings: 6
    )
}
