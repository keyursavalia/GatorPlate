import Foundation

/// Remembers recently loaded photos so a card or Feed row that scrolls back into view does not hit Firestore again.
/// Misses (no photo) are not cached: a photo may still arrive. Wraps any `ImageStore`.
nonisolated final class CachedImageStore: ImageStore, @unchecked Sendable {
    private let base: any ImageStore
    /// `NSCache` is thread-safe and evicts under memory pressure and past `totalCostLimit`.
    private let cache = NSCache<NSString, NSData>()

    init(wrapping base: any ImageStore, maxBytes: Int = AppConfig.photoCacheMaxBytes) {
        self.base = base
        cache.totalCostLimit = maxBytes
    }

    func save(jpeg: Data, forPostID postID: String) async throws {
        try await base.save(jpeg: jpeg, forPostID: postID)
        remember(jpeg, forPostID: postID)
    }

    func load(forPostID postID: String) async throws -> Data? {
        if let cached = cache.object(forKey: postID as NSString) { return cached as Data }
        guard let data = try await base.load(forPostID: postID) else { return nil }
        remember(data, forPostID: postID)
        return data
    }

    private func remember(_ data: Data, forPostID postID: String) {
        cache.setObject(data as NSData, forKey: postID as NSString, cost: data.count)
    }
}
