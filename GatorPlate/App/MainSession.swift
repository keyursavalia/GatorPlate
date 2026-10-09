import Foundation

/// Everything the signed-in UI shares for one session: the live posts listener, navigation, photo cache,
/// alerts settings and the Map/Feed view models. Created when the main UI appears; `prepareSignOut()` runs
/// before sign-out.
@MainActor
final class MainSession {
    let repository: PostsRepository
    let navigation: AppNavigation
    let images: PostImageCache
    let map: MapViewModel
    let feed: FeedViewModel
    let settings: SettingsViewModel

    init(environment: AppEnvironment, profile: UserProfile) {
        let repository = PostsRepository(service: environment.posts)
        let navigation = AppNavigation(posts: repository)
        let images = PostImageCache(store: environment.images)
        self.repository = repository
        self.navigation = navigation
        self.images = images
        self.map = MapViewModel(repository: repository, navigation: navigation, postService: environment.posts,
                                routing: environment.routing, location: environment.location, images: images,
                                currentUid: profile.uid)
        self.feed = FeedViewModel(repository: repository, navigation: navigation, location: environment.location,
                                  images: images)
        self.settings = SettingsViewModel(notifications: environment.notifications, profile: profile)
    }

    func start() {
        repository.start()
        settings.activate()
    }

    /// Stops the listener and removes this device's alert registration while the user can still write.
    func prepareSignOut() async {
        stop()
        await settings.deactivate()
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
        let profile = UserProfile(uid: "mock-uid", displayName: "Mock Student", email: "mock@gmail.com",
                                  accountType: .student, orgName: nil, acceptedTermsVersion: nil,
                                  acceptedTermsAt: nil, notificationsEnabled: false, createdAt: .now)
        let session = MainSession(environment: environment, profile: profile)
        session.start()
        return session
    }
}

extension MapViewModel {
    static var preview: MapViewModel { MainSession.preview.map }
}
