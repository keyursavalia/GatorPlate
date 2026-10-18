import Foundation

/// After an account is deleted, forget this device's per-user state: the post cooldown, the map banner
/// dismissals and the Map/Feed filters and sort. Per-install preferences (calorie display, the camera hint) stay.
nonisolated enum AccountCleanup {
    static let perUserKeys = ["post.lastPublishedAt"]
    static let perUserKeyPrefixes = [BannerDismissals.keyPrefix, PostFilterStore.filterKeyPrefix,
                                     PostFilterStore.sortKeyPrefix]

    static func clearPerUserDefaults(_ defaults: UserDefaults = .standard) {
        for key in perUserKeys { defaults.removeObject(forKey: key) }
        for key in defaults.dictionaryRepresentation().keys
        where perUserKeyPrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
