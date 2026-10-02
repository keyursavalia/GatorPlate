import Observation

@MainActor
@Observable
final class FeedViewModel {
    let repository: PostsRepository
    let location: UserLocationModel
    let navigation: NavigationModel

    init(repository: PostsRepository, location: UserLocationModel, navigation: NavigationModel) {
        self.repository = repository
        self.location = location
        self.navigation = navigation
    }

    /// Active posts, newest first.
    var posts: [FoodPost] { repository.posts }

    /// Before the first snapshot: a spinner, never "No free food".
    var isLoading: Bool { !repository.hasLoaded && repository.posts.isEmpty }

    var showsEmptyState: Bool { repository.hasLoaded && repository.posts.isEmpty }

    func distanceText(to post: FoodPost) -> String? {
        location.distanceText(to: post)
    }

    /// Opens the post's card on the Map tab, where Directions and Open in Maps live.
    func open(_ post: FoodPost) {
        navigation.selectPost(id: post.id)
    }
}
