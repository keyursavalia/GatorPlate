import OSLog
import UIKit

/// UIKit entry points that push needs: remote-notification registration, the APNs device token and the app state
/// for tapped alerts. The only UIKit in `App/`; everything else about alerts lives behind `NotificationService`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by `AppEnvironment.live` to the notification service, which passes the token on to FCM.
    static var deviceTokenHandler: ((Data) -> Void)?
    /// False until the app first becomes active, so a tap that launched the app reads as "cold".
    private static var hasBecomeActive = false
    private var activeObserver: NSObjectProtocol?

    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// For the "Alert tapped (state: ...)" log.
    static func alertAppState() -> AlertOpenRequest.AppState {
        guard hasBecomeActive else { return .cold }
        return UIApplication.shared.applicationState == .active ? .foreground : .background
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { Self.hasBecomeActive = true }
            }
        Logger.app.info("App launched")
        return true
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
