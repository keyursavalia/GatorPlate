import FirebaseMessaging
import OSLog
import UIKit

/// UIKit entry points that push needs: remote-notification registration and the APNs token for FCM.
/// The only UIKit in `App/`; everything else about alerts lives behind `NotificationService`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Logger.app.info("Registered for remote notifications")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on the Simulator and without the Push Notifications capability.
        let nsError = error as NSError
        Logger.app.error("Remote notification registration failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
    }
}
