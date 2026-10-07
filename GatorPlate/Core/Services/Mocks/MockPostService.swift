import Foundation

@MainActor
final class MockPostService: PostService {
    private(set) var posts: [FoodPost]
    private let images: any ImageStore
    /// Set to make `publish` fail, for previews of the error state.
    var publishError: AppError?

    init(posts: [FoodPost] = [.sample], images: any ImageStore = MockImageStore()) {
        self.posts = posts
        self.images = images
    }

    func observeActivePosts() -> AsyncThrowingStream<[FoodPost], Error> {
        let snapshot = posts
        return AsyncThrowingStream { $0.yield(snapshot) }
    }

    func makePostId() -> String { Self.randomPostId() }

    func publish(_ submission: PostSubmission, imageJPEG: Data?) async throws -> FoodPost {
        try await Task.sleep(for: .milliseconds(600))
        if let publishError { throw publishError }
        var hasPhoto = false
        if let imageJPEG {
            hasPhoto = (try? await images.save(jpeg: imageJPEG, forPostId: submission.postId)) != nil
        }
        let now = Date.now
        let post = FoodPost(submission: submission, hasPhoto: hasPhoto, createdAt: now,
                            expiresAt: now.addingTimeInterval(Double(submission.durationMinutes) * 60))
        posts.removeAll { $0.id == post.id }
        posts.append(post)
        return post
    }

    func markGone(postId: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { throw AppError.validation("Post not found") }
        posts[index].status = .gone
        posts[index].updatedAt = .now
    }

    func report(postId: String, reason: String) async throws {}
}

extension FoodPost {
    /// Sample data for mocks and previews.
    nonisolated static var sample: FoodPost {
        mock(id: "sample-post", title: "FREE: Pad Thai - SSB 201",
             description: "Leftover pad thai from the club meeting.", buildingId: "ssb", room: "Room 201",
             items: [FoodItem(name: "Pad Thai", dietary: .vegan, calories: CalorieRange(low: 420, high: 520))],
             dietary: .vegan, allergens: [.soy, .peanuts], minutesLeft: 30)
    }

    /// Sprint 02 map data: active posts at catalog buildings with varied diets and time left.
    nonisolated static var mockCampus: [FoodPost] {
        [
            sample,
            mock(id: "mock-pizza", title: "FREE: Veggie pizza - Library lobby",
                 description: "Six boxes of veggie pizza from a study night. Grab a slice before the final.",
                 buildingId: "library", room: "1st floor lobby",
                 items: [FoodItem(name: "Veggie pizza", dietary: .vegetarian,
                                  calories: CalorieRange(low: 250, high: 300))],
                 dietary: .vegetarian, allergens: [.wheat, .milk], minutesLeft: 8),
            mock(id: "mock-burritos", title: "FREE: Burritos - Chavez Center",
                 description: "Chicken and bean burritos left over from the welcome mixer.",
                 buildingId: "chavez", room: "Jack Adams Hall",
                 items: [FoodItem(name: "Chicken burrito", dietary: .nonVegetarian,
                                  calories: CalorieRange(low: 600, high: 750)),
                         FoodItem(name: "Bean burrito", dietary: .vegetarian,
                                  calories: CalorieRange(low: 500, high: 650))],
                 dietary: .mixed, allergens: [.wheat, .milk], minutesLeft: 4),
            mock(id: "mock-fruit", title: "FREE: Fruit cups - Science 101",
                 description: "Fresh fruit cups from the department seminar, still cold.",
                 buildingId: "science", room: "Room 101",
                 items: [FoodItem(name: "Fruit cup", dietary: .vegan, calories: CalorieRange(low: 80, high: 120))],
                 dietary: .vegan, allergens: [], minutesLeft: 45),
            mock(id: "mock-cookies", title: "FREE: Cookies - The Village",
                 description: "Assorted cookies from the residence hall event.",
                 buildingId: "village", room: nil,
                 items: [FoodItem(name: "Assorted cookies", dietary: .unknown, calories: nil)],
                 dietary: .unknown, allergens: [.wheat, .eggs, .treeNuts], minutesLeft: 22),
        ]
    }

    private nonisolated static func mock(
        id: String, title: String, description: String, buildingId: String, room: String?,
        items: [FoodItem], dietary: DietaryClass, allergens: [Allergen], minutesLeft: Int
    ) -> FoodPost {
        let now = Date.now
        let building = CampusBuilding.byId(buildingId)
        return FoodPost(
            id: id, authorUid: "mock-uid", authorName: "Mock Student", orgName: "Mock Club",
            title: title, description: description,
            items: items, overallDietary: dietary, allergenWarnings: allergens, cautions: [], estimatedServings: 10,
            buildingId: buildingId, locationName: building?.name ?? buildingId, locationDetail: room,
            latitude: building?.coordinate.latitude ?? SFSUCampus.homeCoordinate.latitude,
            longitude: building?.coordinate.longitude ?? SFSUCampus.homeCoordinate.longitude,
            hasPhoto: false, aiGenerated: false, editedAfterAI: false,
            status: .active, createdAt: now.addingTimeInterval(-10 * 60),
            expiresAt: now.addingTimeInterval(Double(minutesLeft) * 60), updatedAt: now)
    }
}
