import Foundation
import OSLog
import UserNotifications

/// `UNUserNotificationCenter` wrapper shared by the Tier A and Tier B services.
nonisolated struct LocalNotifier: Sendable {
    /// Key in `userInfo` (local and remote) that carries the post id.
    static let postIDKey = "postId"

    func permission() async -> NotificationPermission {
        Self.map(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    func requestPermission() async -> NotificationPermission {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            Logger.app.error("Notification authorization request failed")
        }
        return await permission()
    }

    func schedule(_ content: AlertContent) async {
        let payload = UNMutableNotificationContent()
        payload.title = content.title
        payload.body = content.body
        payload.sound = .default
        payload.userInfo = [Self.postIDKey: content.postID]
        // A nil trigger delivers immediately. The post id as identifier replaces a repeat for the same post.
        let request = UNNotificationRequest(identifier: "post-\(content.postID)", content: payload, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.app.error("Scheduling a local notification failed")
        }
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationPermission {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .denied
        }
    }
}

/// Tier A only: in-app banners and local notifications. Used when Firebase is not configured.
nonisolated struct LocalNotificationService: NotificationService {
    private let notifier = LocalNotifier()
    var deliversRemotePush: Bool { false }

    func permission() async -> NotificationPermission { await notifier.permission() }
    func requestPermission() async -> NotificationPermission { await notifier.requestPermission() }
    func enable(uid: String) async throws {}
    func disable(uid: String) async throws {}
    func activate(uid: String) async {}
    func detachDevice(uid: String) async {}
    func scheduleLocal(_ content: AlertContent) async { await notifier.schedule(content) }
}
