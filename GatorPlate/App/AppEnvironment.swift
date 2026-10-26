import SwiftUI

/// Dependency container. View models receive protocols from here, never concrete services.
struct AppEnvironment {
    var auth: any AuthService
    var posts: any PostService
    var analyzer: any FoodAnalyzing
    var location: any LocationProviding
    var images: any ImageStore
    var camera: any CameraCapturing
    var routing: any RoutingService
    var notifications: any NotificationService
    var account: any AccountService
    /// Remote Config settings (model names, kill switches, notices, update gates, filter lists).
    var runtime: any RuntimeConfigProviding
    var blocking: any BlockingService
    var admin: any AdminService

    /// Built once, on first use (after `FirebaseApp.configure()` in `GatorPlateApp.init`).
    static let live = makeLive()

    private static func makeLive() -> AppEnvironment {
        let images = FirebaseStorageImageStore()
        let notifications = FirebaseNotificationService(
            registerForRemoteNotifications: AppDelegate.registerForRemoteNotifications,
            appState: AppDelegate.alertAppState)
        AppDelegate.deviceTokenHandler = { notifications.apnsTokenDidArrive($0) }
        let runtime = FirebaseRuntimeConfig()
        return AppEnvironment(auth: FirebaseAuthService(), posts: FirestorePostService(images: images),
                              analyzer: GeminiFoodAnalyzer(runtime: runtime), location: CoreLocationProvider(),
                              images: images, camera: CameraService(), routing: MapKitRoutingService(),
                              notifications: notifications, account: FirebaseAccountService(), runtime: runtime,
                              blocking: FirestoreBlockingService(), admin: FirebaseAdminService())
    }

    #if DEBUG
    static var mock: AppEnvironment {
        let images = MockImageStore()
        return AppEnvironment(auth: MockAuthService(), posts: MockPostService(images: images),
                              analyzer: MockFoodAnalyzer(), location: MockLocationProvider(),
                              images: images, camera: MockCameraService(), routing: MockRoutingService(),
                              notifications: MockNotificationService(), account: MockAccountService(),
                              runtime: MockRuntimeConfig(), blocking: MockBlockingService(),
                              admin: MockAdminService(isAdmin: false))
    }
    #endif
}

extension EnvironmentValues {
    /// The app injects `.live` at the root; the default is the same instance.
    @Entry var appEnvironment: AppEnvironment = .live
}
