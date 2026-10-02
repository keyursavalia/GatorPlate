import SwiftUI

/// Dependency container. Views and view models receive services through this, never directly.
nonisolated struct AppEnvironment: Sendable {
    var auth: any AuthService
    var posts: any PostService
    var analyzer: any FoodAnalyzing
    var location: any LocationProviding
    var images: any ImageStore
    var camera: any CameraProviding
    /// Session-wide anti-spam memory for the Post flow (in memory only).
    var cooldown: PostCooldown
    /// True once `FirebaseApp.configure()` has run. Set by the app entry point.
    var isFirebaseConfigured: Bool

    /// Used by previews and tests.
    static let mock = AppEnvironment(
        auth: MockAuthService(),
        posts: MockPostService(),
        analyzer: MockFoodAnalyzer(),
        location: MockLocationProvider(),
        images: MockImageStore(),
        camera: MockCameraService(),
        cooldown: PostCooldown(),
        isFirebaseConfigured: false
    )

    /// Services backed by Firebase where an implementation exists; mocks for the rest until their sprint.
    @MainActor
    static func live(firebaseConfigured: Bool) -> AppEnvironment {
        var environment = AppEnvironment.mock
        environment.location = CoreLocationProvider()
        environment.camera = CameraService()
        environment.isFirebaseConfigured = firebaseConfigured
        if firebaseConfigured {
            environment.auth = FirebaseAuthService()
            environment.analyzer = GeminiFoodAnalyzer()
            let images = FirestoreImageStore()
            environment.images = images
            environment.posts = FirestorePostService(images: images)
        }
        return environment
    }
}

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment = .mock
}
