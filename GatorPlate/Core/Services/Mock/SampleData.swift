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

    /// Mock posts at verified campus buildings for the Sprint 2 map. They expire 8 to 52 minutes after `now`.
    static func mapPosts(now: Date = Date()) -> [FoodPost] {
        func make(
            _ id: String, title: String, org: String, building: String, detail: String,
            dietary: DietaryClass, allergens: [Allergen], calories: CalorieRange, minutes: Int
        ) -> FoodPost? {
            guard let spot = CampusBuildings.building(id: building) else { return nil }
            var result = Self.post(now: now, id: id)
            result.title = title
            result.orgName = org
            result.items = [FoodItem(name: title, dietary: dietary, calories: calories)]
            result.overallDietary = dietary
            result.allergenWarnings = allergens
            result.buildingId = spot.id
            result.locationName = spot.name
            result.locationDetail = detail
            result.latitude = spot.coordinate.latitude
            result.longitude = spot.coordinate.longitude
            result.expiresAt = now.addingTimeInterval(TimeInterval(minutes * 60))
            return result
        }
        return [
            make("map-1", title: "FREE: Pad Thai", org: "Thai Student Association", building: "student-center",
                 detail: "Room 201", dietary: .vegetarian, allergens: [.soy, .peanuts],
                 calories: CalorieRange(low: 420, high: 520), minutes: 28),
            make("map-2", title: "FREE: Cheese pizza", org: "Gator Coding Club", building: "science",
                 detail: "Lobby", dietary: .vegetarian, allergens: [.milk, .wheat],
                 calories: CalorieRange(low: 280, high: 350), minutes: 8),
            make("map-3", title: "FREE: Chicken burritos", org: "Latinx Student Union", building: "library",
                 detail: "Front steps", dietary: .nonVegetarian, allergens: [.wheat],
                 calories: CalorieRange(low: 500, high: 650), minutes: 52),
            make("map-4", title: "FREE: Vegan wraps", org: "Green Gators", building: "village",
                 detail: "Courtyard", dietary: .vegan, allergens: [.sesame, .wheat],
                 calories: CalorieRange(low: 300, high: 380), minutes: 20),
        ].compactMap { $0 }
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

    static let analysisCautious = FoodAnalysisResult(
        title: "FREE: Veggie wraps and fruit",
        description: "Veggie wraps and cut fruit. Filling is unclear, so dietary info is unknown. May contain wheat and sesame.",
        items: [
            FoodItem(name: "Veggie wrap", dietary: .unknown, calories: CalorieRange(low: 250, high: 380)),
            FoodItem(name: "Fruit cup", dietary: .vegan, calories: CalorieRange(low: 60, high: 120)),
        ],
        overallDietary: .unknown,
        allergenWarnings: [.wheat, .sesame],
        cautions: ["Keep cold food chilled or discard after 2 hours."],
        estimatedServings: 10
    )

    static let analysisNoAllergens = FoodAnalysisResult(
        title: "FREE: Bottled water",
        description: "Sealed bottled water, about two dozen bottles on a table by the entrance.",
        items: [FoodItem(name: "Bottled water", dietary: .unknown, calories: nil)],
        overallDietary: .unknown,
        allergenWarnings: [],
        cautions: [],
        estimatedServings: 24,
        allergensUnverified: true
    )
}
