import Foundation

/// Version gates from Remote Config. Pure. An unreadable app version or an empty / invalid remote version never
/// shows a gate, so a bad publish can't lock anyone out.
nonisolated enum UpdateGate {
    /// Below `minimum_app_version`: the full-screen Update required screen.
    static func isRequired(current: AppVersion?, minimum: AppVersion?) -> Bool {
        guard let current, let minimum else { return false }
        return current < minimum
    }

    /// Below `recommended_app_version` (and not already required): a dismissible banner.
    static func isRecommended(current: AppVersion?, recommended: AppVersion?) -> Bool {
        guard let current, let recommended else { return false }
        return current < recommended
    }

    /// Device-wide (not per user), so `AccountCleanup` leaves it alone.
    static func dismissalKey(_ version: AppVersion) -> String {
        "update.dismissed.\(version)"
    }
}
