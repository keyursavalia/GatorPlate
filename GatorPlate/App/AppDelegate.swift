import OSLog
import UIKit

/// UIKit entry points that push needs: remote-notification registration and the APNs device token.
/// The only UIKit in `App/`; everything else about alerts lives behind `NotificationService`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by `AppEnvironment.live` to the notification service, which passes the token on to FCM.
    static var deviceTokenHandler: ((Data) -> Void)?

    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Logger.app.info("Registered for remote notifications")
        Self.deviceTokenHandler?(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on the Simulator and without the Push Notifications capability.
        let nsError = error as NSError
        Logger.app.error("Remote notification registration failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
    }
}
