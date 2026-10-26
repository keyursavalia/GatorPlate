import FirebaseMessaging
import OSLog
import UserNotifications

/// Tapped alerts: the `UNUserNotificationCenterDelegate` methods, and clearing opened alerts.
extension FirebaseNotificationService {
    /// Removes the opened alert, and any other delivered alert for the same post, from Notification Center.
    func clearDelivered(postId: String, notificationId: String) {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])
        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { NotificationTap.postId(from: $0.request.content.userInfo) == postId }
                .map(\.request.identifier)
            if !ids.isEmpty { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids) }
        }
        center.setBadgeCount(0) { error in
            if error != nil { Logger.services.error("Couldn't clear the app badge") }
        }
    }

    /// "present" / "missing" / "rejected", never the ID itself.
    nonisolated static func postIdCheck(_ userInfo: [AnyHashable: Any]) -> String {
        guard userInfo[AppConfig.notificationPostIdKey] != nil else { return "missing" }
        return NotificationTap.postId(from: userInfo) == nil ? "rejected" : "present"
    }
}

/// Completion-handler variants on purpose: the `async` ones run on the global executor and finish off the main
/// thread, which iOS 18+ can kill the app for ("Call must be made on main thread"), so a tap looked like the app
/// never opened. Each handler is called exactly once, on the main actor.
extension FirebaseNotificationService: UNUserNotificationCenterDelegate {
    /// Alerts show while the app is open too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let complete = UncheckedSendable(completionHandler)
        Task { @MainActor in complete.value([.banner, .list, .sound]) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        let userInfo = request.content.userInfo
        let tap = NotificationTap.parse(userInfo)
        let check = Self.postIdCheck(userInfo)
        let notificationId = request.identifier
        // With the proxy off, FCM learns about the open from here (delivery metrics only).
        Messaging.messaging().appDidReceiveMessage(userInfo)
        let complete = UncheckedSendable(completionHandler)
        Task { @MainActor in
            Logger.ui.info("Alert postId \(check, privacy: .public)")
            didOpenNotification(tap, notificationId: notificationId)
            complete.value()
        }
    }
}

/// UserNotifications' completion handlers aren't marked `Sendable`; each one is called once, on the main actor.
private nonisolated struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

