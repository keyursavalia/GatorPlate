import Foundation

/// Client-side anti-spam: one post per `AppConfig.postCooldownSeconds`. Stores only the last publish time,
/// so it survives relaunches. Not a draft; no post content is stored.
nonisolated struct PostCooldown {
    private static let key = "post.lastPublishedAt"

    var defaults: UserDefaults = .standard
    var now: @Sendable () -> Date = { .now }

    /// Whole seconds until the next post is allowed; 0 when posting is allowed.
    func secondsRemaining() -> Int {
        guard let last = defaults.object(forKey: Self.key) as? Date else { return 0 }
        let elapsed = now().timeIntervalSince(last)
        // A clock moved backwards should not lock the user out.
        guard elapsed >= 0 else { return 0 }
        return max(0, Int((Double(AppConfig.postCooldownSeconds) - elapsed).rounded(.up)))
    }

    func recordPublish() {
        defaults.set(now(), forKey: Self.key)
    }
}
