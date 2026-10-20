import Foundation

/// Everything the main UI shares for one guest or account session: the live posts listener, navigation, photo cache,
/// alerts settings, location access, the Map/Feed filter and its results, the first-run permission prompts and the
/// Map/Feed view models. Created when the main UI appears; `prepareSignOut()` runs before sign-out.
@MainActor
final class MainSession {
    /// The guest or account this session belongs to.
    let uid: String
    let repository: PostsRepository
    let navigation: AppNavigation
    let images: PostImageCache
    /// The Map/Feed filter (device only) and the posts it lets through.
    let filters: PostFilterStore
    let browse: BrowseResults
    let map: MapViewModel
    let feed: FeedViewModel
    let settings: SettingsViewModel
    /// Location on/off for Settings > Location and the map's location button.
    let locationAccess: LocationAccess
    let permissions: FirstRunPermissions

    init(environment: AppEnvironment, profile: UserProfile) {
        self.uid = profile.uid
        let repository = PostsRepository(service: environment.posts)
        let notifications = environment.notifications
        let postService = environment.posts
        let navigation = AppNavigation(posts: repository, alertResolved: { notifications.alertHandled($0) },
                                       lookup: { try await postService.fetchPost(id: $0) })
        let images = PostImageCache(store: environment.images)
        let settings = SettingsViewModel(notifications: environment.notifications, profile: profile)
        let filters = PostFilterStore(uid: profile.uid)
        let reported = ReportedPosts(uid: profile.uid)
        let locationAccess = LocationAccess(location: environment.location)
        let browse = BrowseResults(filters: filters, repository: repository, navigation: navigation,
                                   location: environment.location, reported: reported, notificationPicks: {
                                       // "Use my notification filters" shows only while Custom notifications are on.
                                       settings.alertsEnabled ? AlertFilterMatcher.effective(settings.alertFilters) : nil
                                   })
        self.repository = repository
        self.navigation = navigation
        self.images = images
        self.filters = filters
        self.browse = browse
        self.map = MapViewModel(repository: repository, navigation: navigation, postService: environment.posts,
                                routing: environment.routing, location: environment.location,
                                locationAccess: locationAccess, images: images, browse: browse,
                                reportedPosts: reported, currentUid: profile.uid)
        self.feed = FeedViewModel(repository: repository, navigation: navigation, location: environment.location,
                                  images: images, browse: browse)
        self.settings = settings
        self.locationAccess = locationAccess
        self.permissions = FirstRunPermissions(location: environment.location,
                                               notifications: environment.notifications,
                                               optIn: { await settings.optInFromChain() })
    }

    func start() {
        repository.start()
        browse.start()
        settings.activate()
    }

    /// Stops the listener and removes this device's alert registration while the user can still write.
    func prepareSignOut() async {
        // Not in `stop()`: the post-flow cover makes the tabs disappear and come back mid-session.
        permissions.cancel()
        stop()
        await settings.deactivate()
    }

    /// Account deletion: like `prepareSignOut` but without the Firestore write (the server deletes the profile).
    func stopForDeletion() {
        permissions.cancel()
        stop()
        settings.forgetForDeletedAccount()
    }

    /// Removes the listener. Call before signing out.
    func stop() {
        navigation.selectedPostId = nil
        browse.stop()
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
        // Previews never fire the first-run prompts.
        session.permissions.cancel()
        session.start()
        return session
    }
}

extension MapViewModel {
    static var preview: MapViewModel { MainSession.preview.map }
}
