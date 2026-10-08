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

    static var live: AppEnvironment {
        let images = FirebaseStorageImageStore()
        return AppEnvironment(auth: FirebaseAuthService(), posts: FirestorePostService(images: images),
                              analyzer: GeminiFoodAnalyzer(), location: CoreLocationProvider(),
                              images: images, camera: CameraService(), routing: MapKitRoutingService(),
                              notifications: FirebaseNotificationService(
                                  registerForRemoteNotifications: AppDelegate.registerForRemoteNotifications))
    }

    static var mock: AppEnvironment {
        let images = MockImageStore()
        return AppEnvironment(auth: MockAuthService(), posts: MockPostService(images: images),
                              analyzer: MockFoodAnalyzer(), location: MockLocationProvider(),
                              images: images, camera: MockCameraService(), routing: MockRoutingService(),
                              notifications: MockNotificationService())
    }
}

extension EnvironmentValues {
    /// Defaults to mocks so previews work; the app injects `.live`.
    @Entry var appEnvironment: AppEnvironment = .mock
}
