import Foundation

/// App-level view of notification permission, free of UserNotifications types.
nonisolated enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    /// Includes provisional and ephemeral authorization.
    case authorized

    var isAuthorized: Bool { self == .authorized }
}
