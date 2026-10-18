import Foundation

/// After an account is deleted, forget this device's per-user state: the post cooldown and the map banner
/// dismissals. Per-install preferences (calorie display, the camera hint) stay.
nonisolated enum AccountCleanup {
    static let perUserKeys = ["post.lastPublishedAt"]

    static func clearPerUserDefaults(_ defaults: UserDefaults = .standard) {
        for key in perUserKeys { defaults.removeObject(forKey: key) }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(BannerDismissals.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
