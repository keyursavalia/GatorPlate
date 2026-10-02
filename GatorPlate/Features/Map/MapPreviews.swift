import SwiftUI

/// Builds a fully mocked `MapViewModel` for previews.
@MainActor
enum MapPreviews {
    static func mapViewModel(
        posts: [FoodPost] = SampleData.mapPosts(),
        userID: String = "someone-else",
        location: any LocationProviding = MockLocationProvider(),
        routing: any RoutingService = MockRoutingService()
    ) -> MapViewModel {
        let service = MockPostService(posts: posts)
        let repository = PostsRepository(service: service)
        repository.apply(snapshot: posts)
        let locationModel = UserLocationModel(location: location)
        locationModel.apply(status: .authorizedFull)
        locationModel.apply(location: SampleData.campusCoordinate)
        return MapViewModel(
            repository: repository,
            location: locationModel,
            navigation: NavigationModel(),
            routing: routing,
            actions: PostActionsModel(service: service, currentUserID: userID)
        )
    }
}
