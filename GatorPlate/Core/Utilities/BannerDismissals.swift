import Foundation

/// "Not now" on a map location banner, remembered on this device: the same banner returns only after
/// `AppConfig.locationBannerSnoozeDays`. Stored under `map.dismissedLocationBanner.<name>` (the date dismissed).
nonisolated struct BannerDismissals {
    static let keyPrefix = "map.dismissedLocationBanner."

    private let defaults: UserDefaults
    private let snooze: TimeInterval

    init(defaults: UserDefaults = .standard,
         snooze: TimeInterval = TimeInterval(AppConfig.locationBannerSnoozeDays) * 24 * 60 * 60) {
        self.defaults = defaults
        self.snooze = snooze
    }

    func isSnoozed(_ name: String, now: Date = .now) -> Bool {
        guard let dismissedAt = defaults.object(forKey: Self.keyPrefix + name) as? Date else { return false }
        return now.timeIntervalSince(dismissedAt) < snooze
    }

    func dismiss(_ name: String, now: Date = .now) {
        defaults.set(now, forKey: Self.keyPrefix + name)
    }
}
