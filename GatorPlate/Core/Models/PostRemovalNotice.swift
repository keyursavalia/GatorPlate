import Foundation

/// The poster's most recent removed post (`users/{uid}.lastRemoval`, written by the moderation functions). The app
/// shows it once as a banner, so posters learn about a removal even without push notifications.
nonisolated struct PostRemovalNotice: Codable, Equatable, Sendable {
    /// `postRemovals` category: unsafe, offensive, misleading, trading, screened, filtered or admin.
    var category: String
    var removedAt: Date

    var message: String {
        switch category {
        case "unsafe": "Your post was removed after a report that it was unsafe to eat."
        case "screened": "Your post was removed: a photo didn't pass our checks. Post again with photos of just the food."
        case "filtered": "Your post was removed: it had language that isn't allowed on GatorPlate."
        case "admin": "Your post was removed by a moderator."
        default: "Your post was removed after reports from other students."
        }
    }
}

/// Remembers, per user on this phone, the last removal notice shown (cleared with the account by `AccountCleanup`).
nonisolated enum RemovalNoticeTracker {
    static let keyPrefix = "notice.removalSeen."
    /// Older removals aren't announced (e.g. on a new phone).
    static let maxAge: TimeInterval = 7 * 24 * 3600

    static func shouldShow(_ notice: PostRemovalNotice?, uid: String, defaults: UserDefaults = .standard,
                           now: Date = .now) -> Bool {
        guard let notice, now.timeIntervalSince(notice.removedAt) < maxAge else { return false }
        let seen = defaults.double(forKey: keyPrefix + uid)
        return notice.removedAt.timeIntervalSince1970 > seen
    }

    static func markSeen(_ notice: PostRemovalNotice, uid: String, defaults: UserDefaults = .standard) {
        defaults.set(notice.removedAt.timeIntervalSince1970, forKey: keyPrefix + uid)
    }
}
