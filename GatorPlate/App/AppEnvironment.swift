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

    static var live: AppEnvironment {
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
                              blocking: FirestoreBlockingService())
    }

    static var mock: AppEnvironment {
        let images = MockImageStore()
        return AppEnvironment(auth: MockAuthService(), posts: MockPostService(images: images),
                              analyzer: MockFoodAnalyzer(), location: MockLocationProvider(),
                              images: images, camera: MockCameraService(), routing: MockRoutingService(),
                              notifications: MockNotificationService(), account: MockAccountService(),
                              runtime: MockRuntimeConfig(), blocking: MockBlockingService())
    }
}

extension EnvironmentValues {
    /// Defaults to mocks so previews work; the app injects `.live`.
    @Entry var appEnvironment: AppEnvironment = .mock
}
