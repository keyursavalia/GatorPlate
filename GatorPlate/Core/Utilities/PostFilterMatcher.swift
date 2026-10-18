import Foundation

/// Applies the Map/Feed filter. Diet, places, allergens and foods go through `AlertFilterMatcher` (the same answers
/// as Custom notifications and `functions/src/filters.ts`); this adds only time left and walking distance.
/// AND across categories, OR within one; an empty category doesn't restrict.
nonisolated enum PostFilterMatcher {
    /// The posts to show and how many the filter hid.
    struct Result: Equatable, Sendable {
        var posts: [FoodPost] = []
        var hiddenCount = 0

        var totalCount: Int { posts.count + hiddenCount }
    }

    static func matches(_ post: FoodPost, filter: PostFilter, now: Date, userLocation: Coordinate?) -> Bool {
        guard AlertFilterMatcher.matches(post, filters: filter.picks) else { return false }
        if let minimum = filter.minMinutesLeft, minutesLeft(post, now: now) < minimum { return false }
        // Without a location the distance filter is ignored: it must never hide every post.
        if let maximum = filter.maxWalkMinutes, let userLocation,
           DistanceText.walkMinutes(meters: userLocation.distance(to: post.coordinate)) > maximum { return false }
        return true
    }

    /// Filters `posts` (order kept). `keeping` is a post the student opened on purpose (alert, "View on map", a
    /// Feed row): it's always shown and never counted as hidden.
    static func visible(_ posts: [FoodPost], filter: PostFilter, now: Date, userLocation: Coordinate?,
                        keeping keptId: String? = nil) -> Result {
        guard !filter.isEmpty else { return Result(posts: posts) }
        var result = Result()
        for post in posts {
            if post.id == keptId || matches(post, filter: filter, now: now, userLocation: userLocation) {
                result.posts.append(post)
            } else {
                result.hiddenCount += 1
            }
        }
        return result
    }

    /// Feed order. `posts` arrive newest first; ties fall back to that order, then the ID, so rows never jump.
    /// Nearest without a location keeps newest first.
    static func sorted(_ posts: [FoodPost], by sort: FeedSort, userLocation: Coordinate?) -> [FoodPost] {
        switch sort {
        case .newest:
            return posts
        case .endingSoon:
            return stableSorted(posts) { $0.expiresAt < $1.expiresAt }
        case .nearest:
            guard let userLocation else { return posts }
            let meters = Dictionary(posts.map { ($0.id, userLocation.distance(to: $0.coordinate)) },
                                    uniquingKeysWith: { first, _ in first })
            return stableSorted(posts) { (meters[$0.id] ?? 0) < (meters[$1.id] ?? 0) }
        }
    }

    /// Whole minutes left, rounded up like `TimeRemainingPill`, so a post showing "10 min left" counts as 10+.
    static func minutesLeft(_ post: FoodPost, now: Date) -> Int {
        max(0, Int((post.expiresAt.timeIntervalSince(now) / 60).rounded(.up)))
    }

    private static func stableSorted(_ posts: [FoodPost], by isBefore: (FoodPost, FoodPost) -> Bool) -> [FoodPost] {
        posts.enumerated().sorted { lhs, rhs in
            if isBefore(lhs.element, rhs.element) { return true }
            if isBefore(rhs.element, lhs.element) { return false }
            if lhs.offset != rhs.offset { return lhs.offset < rhs.offset }
            return lhs.element.id < rhs.element.id
        }
        .map(\.element)
    }
}
