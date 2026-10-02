import Foundation

nonisolated enum NotificationPermission: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// What an alert says. Built from a post, never carries personal data beyond the post's own title and place.
nonisolated struct AlertContent: Equatable, Sendable {
    var postID: String
    var title: String
    var body: String
}
