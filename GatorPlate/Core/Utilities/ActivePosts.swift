import Foundation

/// The posts the map and feed show: active as of `now`, newest first.
nonisolated enum ActivePosts {
    static func filter(_ posts: [FoodPost], now: Date) -> [FoodPost] {
        posts
            .filter { $0.isActive(now: now) }
            .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
    }
}
