import Foundation

/// A tapped free food alert waiting to open its post. The notification service keeps it until navigation has
/// opened the post (or shown "no longer available"), so a session restart or a cover on screen never loses it.
nonisolated struct AlertOpenRequest: Equatable, Sendable {
    /// What the app was doing when the alert was tapped. Logged as evidence; never changes behavior.
    enum AppState: String, Sendable {
        /// The tap launched the app.
        case cold
        case background
        case foreground
    }

    let postId: String
    let appState: AppState
    /// Notification Center identifier, so the alert can be cleared once its post is open.
    let notificationId: String
}
