import Foundation
import Observation

/// The Feed: the same live posts as the map, through the same Map/Feed filter, in the chosen order (newest first by
/// default), as a complete non-map way to find food.
@MainActor
@Observable
final class FeedViewModel {
    enum Content: Equatable {
        case loading
        case failed
        /// Nothing posted, or only posts this account reported or whose posters it blocked.
        case empty
        /// Posts exist but the filter hides every one.
        case allHidden
        case posts
    }

    let images: PostImageCache?
    /// The shared Map/Feed filter and the posts it lets through.
    let browse: BrowseResults

    @ObservationIgnored private let repository: PostsRepository
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let location: any LocationProviding

    init(repository: PostsRepository, navigation: AppNavigation, location: any LocationProviding,
         images: PostImageCache?, browse: BrowseResults) {
        self.repository = repository
        self.navigation = navigation
        self.location = location
        self.images = images
        self.browse = browse
    }

    /// Filtered, in the chosen order. Sorts are facts about the post only (R6).
    var posts: [FoodPost] {
        PostFilterMatcher.sorted(browse.posts, by: browse.filters.sort, userLocation: browse.userLocation)
    }

    var content: Content {
        switch repository.phase {
        case .loading: repository.hasError ? .failed : .loading
        case .loaded:
            // Counted after reported and blocked posts are left out: only the filter makes "Nothing matches".
            if browse.totalCount == 0 { .empty } else if browse.posts.isEmpty { .allHidden } else { .posts }
        }
    }

    /// Shown above the list when the listener is retrying but older posts are still on screen.
    var showsRetryBanner: Bool {
        repository.hasError && repository.phase == .loaded
    }

    // MARK: Filters

    var filterCount: Int { browse.filters.filter.activeCount }
    var hiddenCount: Int { browse.hiddenCount }
    var chips: [PostFilterChip] { PostFilterChip.chips(for: browse.filters.filter) }

    var isFilterSheetPresented: Bool {
        get { navigation.filterSheetTab == .feed }
        set { navigation.filterSheetTab = newValue ? .feed : nil }
    }

    func openFilters() {
        isFilterSheetPresented = true
    }

    func remove(_ chip: PostFilterChip) {
        browse.filters.filter = chip.removed(from: browse.filters.filter)
    }

    func clearFilters() {
        browse.filters.clear()
    }

    func filterSheetDidDismiss() {
        navigation.filterSheetDidDismiss()
    }

    /// "1 post hidden by filters" / "3 posts hidden by filters".
    var hiddenFooter: String? {
        guard hiddenCount > 0 else { return nil }
        return hiddenCount == 1 ? "1 post hidden by filters" : "\(hiddenCount) posts hidden by filters"
    }

    // MARK: Rows

    /// Last known distance; the feed doesn't start location updates on its own.
    func distanceText(to post: FoodPost) -> String? {
        DistanceText.away(meters: location.distance(to: post.coordinate))
    }

    /// Opens the post on the map with its card (always, even if the filter would hide it there).
    func open(_ post: FoodPost) {
        navigation.selectPost(id: post.id)
    }
}
