import Foundation
import Observation

/// The Feed: the same live posts as the map, newest first, as a complete non-map way to find food.
@MainActor
@Observable
final class FeedViewModel {
    enum Content: Equatable {
        case loading
        case failed
        case empty
        case posts
    }

    let images: PostImageCache?

    @ObservationIgnored private let repository: PostsRepository
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let location: any LocationProviding

    init(repository: PostsRepository, navigation: AppNavigation, location: any LocationProviding,
         images: PostImageCache?) {
        self.repository = repository
        self.navigation = navigation
        self.location = location
        self.images = images
    }

    /// Newest first.
    var posts: [FoodPost] { repository.activePosts }

    var content: Content {
        switch repository.phase {
        case .loading: repository.hasError ? .failed : .loading
        case .loaded: posts.isEmpty ? .empty : .posts
        }
    }

    /// Shown above the list when the listener is retrying but older posts are still on screen.
    var showsRetryBanner: Bool {
        repository.hasError && repository.phase == .loaded
    }

    /// Last known distance; the feed doesn't start location updates on its own.
    func distanceText(to post: FoodPost) -> String? {
        DistanceText.away(meters: location.distance(to: post.coordinate))
    }

    /// Opens the post on the map with its card.
    func open(_ post: FoodPost) {
        navigation.selectPost(id: post.id)
    }
}
