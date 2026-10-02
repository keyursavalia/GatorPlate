import Observation
import OSLog
import UIKit
import UserNotifications

/// Hands notification taps from UIKit to SwiftUI. A tap that launches the app arrives before the UI exists, so the
/// post id is held here until `NotificationsModel` consumes it.
@MainActor
@Observable
final class NotificationTapRelay {
    static let shared = NotificationTapRelay()
    private(set) var pendingPostID: String?

    func receive(postID: String) { pendingPostID = postID }

    func consume() -> String? {
        defer { pendingPostID = nil }
        return pendingPostID
    }
}

/// Owns the notification center delegate. Foreground pushes are suppressed because the in-app banner covers them.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let postID = response.notification.request.content.userInfo[LocalNotifier.postIDKey] as? String else { return }
        await MainActor.run { NotificationTapRelay.shared.receive(postID: postID) }
    }
}
