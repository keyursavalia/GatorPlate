import Foundation

/// Everything the signed-in UI shares for one session: the live posts listener, navigation, photo cache and
/// the Map/Feed view models. Created when the main UI appears; `stop()` runs before sign-out.
@MainActor
final class MainSession {
    let repository: PostsRepository
    let navigation: AppNavigation
    let images: PostImageCache
    let map: MapViewModel
    let feed: FeedViewModel

    init(environment: AppEnvironment, currentUid: String?) {
        let repository = PostsRepository(service: environment.posts)
        let navigation = AppNavigation(posts: repository)
        let images = PostImageCache(store: environment.images)
        self.repository = repository
        self.navigation = navigation
        self.images = images
        self.map = MapViewModel(repository: repository, navigation: navigation, postService: environment.posts,
                                routing: environment.routing, location: environment.location, images: images,
                                currentUid: currentUid)
        self.feed = FeedViewModel(repository: repository, navigation: navigation, location: environment.location,
                                  images: images)
    }

    func start() {
        repository.start()
    }

    /// Removes the listener and ends any route. Call before signing out.
    func stop() {
        map.endRoute()
        navigation.selectedPostId = nil
        repository.stop()
    }
}

extension MainSession {
    /// Mock campus posts for previews.
    static var preview: MainSession {
        var environment = AppEnvironment.mock
        environment.posts = MockPostService(posts: FoodPost.mockCampus)
        let session = MainSession(environment: environment, currentUid: "mock-uid")
        session.start()
        return session
    }
}

extension MapViewModel {
    static var preview: MapViewModel { MainSession.preview.map }
}
