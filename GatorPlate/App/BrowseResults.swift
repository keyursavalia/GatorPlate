import Foundation
import Observation

/// The filtered posts both tabs show (one filter for Map and Feed). `PostsRepository` stays unfiltered; posts this
/// account reported are left out (unless open). This re-filters when the posts, the filter, the reported posts or
/// the open post change, every expiry tick while "Time left" is on, and
/// after the student moves `AppConfig.browseLocationChangeMeters` while distance matters. `result` is reassigned
/// only when it really changes, so nothing re-renders per location fix or per frame.
@MainActor
@Observable
final class BrowseResults {
    private(set) var result = PostFilterMatcher.Result()
    /// The location the current result used (the last fix, held until the student moves enough).
    private(set) var userLocation: Coordinate?

    let filters: PostFilterStore
    /// Posts this account reported, hidden from both tabs.
    let reported: ReportedPosts?

    @ObservationIgnored private let repository: PostsRepository
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let readNotificationPicks: () -> AlertFilters?
    @ObservationIgnored private let tickInterval: Duration
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var isObserving = false

    init(filters: PostFilterStore, repository: PostsRepository, navigation: AppNavigation,
         location: any LocationProviding, reported: ReportedPosts? = nil,
         notificationPicks: @escaping () -> AlertFilters? = { nil },
         now: @escaping () -> Date = { .now },
         tickInterval: Duration = .seconds(AppConfig.postsExpiryTickSeconds)) {
        self.filters = filters
        self.reported = reported
        self.repository = repository
        self.navigation = navigation
        self.location = location
        self.now = now
        self.readNotificationPicks = notificationPicks
        self.tickInterval = tickInterval
    }

    var posts: [FoodPost] { result.posts }
    var hiddenCount: Int { result.hiddenCount }
    var totalCount: Int { result.totalCount }

    /// The student's Custom notifications picks for "Use my notification filters", or nil when notifications are
    /// off or for all free food.
    var notificationPicks: AlertFilters? { readNotificationPicks() }

    /// Starts following changes. Idempotent.
    func start() {
        guard !isObserving else { return }
        isObserving = true
        recompute()
        observe()
    }

    func stop() {
        isObserving = false
        ticker?.cancel()
        ticker = nil
    }

    /// Re-filters now. Internal so tests can drive it.
    func recompute() {
        let filter = filters.filter
        updateLocation()
        let next = PostFilterMatcher.visible(candidates, filter: filter, now: now(),
                                             userLocation: userLocation, keeping: navigation.selectedPostId)
        if next != result { result = next }
        updateTicker(needed: filter.minMinutesLeft != nil)
    }

    /// Would this post be hidden if it weren't open? ("Hidden by your filters" in the map sheet.)
    func isHiddenByFilters(_ post: FoodPost) -> Bool {
        !filters.filter.isEmpty
            && !PostFilterMatcher.matches(post, filter: filters.filter, now: now(), userLocation: userLocation)
    }

    /// The posts the filter would show with `filter` instead of the current one ("Showing 3 of 7" while editing).
    func preview(_ filter: PostFilter) -> PostFilterMatcher.Result {
        PostFilterMatcher.visible(candidates, filter: filter, now: now(), userLocation: userLocation)
    }

    // MARK: Private

    /// Active posts minus the ones this account reported, except the open post.
    private var candidates: [FoodPost] {
        guard let reported, !reported.ids.isEmpty else { return repository.activePosts }
        let selected = navigation.selectedPostId
        return repository.activePosts.filter { !reported.contains($0.id) || $0.id == selected }
    }

    /// Keeps the previous fix until the student has moved far enough, so GPS jitter changes nothing.
    private func updateLocation() {
        guard let fix = location.lastCoordinate else {
            if userLocation != nil { userLocation = nil }
            return
        }
        guard let current = userLocation,
              current.distance(to: fix) < AppConfig.browseLocationChangeMeters else {
            userLocation = fix
            return
        }
    }

    /// Follows the inputs with Observation; each change re-arms the tracking after the new values land.
    private func observe() {
        withObservationTracking {
            _ = repository.activePosts
            _ = filters.filter
            _ = reported?.ids
            _ = navigation.selectedPostId
            _ = location.lastCoordinate
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isObserving else { return }
                self.recompute()
                self.observe()
            }
        }
    }

    private func updateTicker(needed: Bool) {
        guard needed else {
            ticker?.cancel()
            ticker = nil
            return
        }
        guard ticker == nil, isObserving else { return }
        let interval = tickInterval
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                self?.recompute()
            }
        }
    }
}
