import SwiftUI

/// Dependency container. Views and view models receive services through this, never directly.
nonisolated struct AppEnvironment: Sendable {
    var auth: any AuthService
    var posts: any PostService
    var analyzer: any FoodAnalyzing
    var location: any LocationProviding
    var images: any ImageStore
    /// True once `FirebaseApp.configure()` has run. Set by the app entry point.
    var isFirebaseConfigured: Bool

    /// Used by previews and tests.
    static let mock = AppEnvironment(
        auth: MockAuthService(),
        posts: MockPostService(),
        analyzer: MockFoodAnalyzer(),
        location: MockLocationProvider(),
        images: MockImageStore(),
        isFirebaseConfigured: false
    )

    /// Services backed by Firebase where an implementation exists; mocks for the rest until their sprint.
    static func live(firebaseConfigured: Bool) -> AppEnvironment {
        var environment = AppEnvironment.mock
        environment.isFirebaseConfigured = firebaseConfigured
        if firebaseConfigured {
            environment.auth = FirebaseAuthService()
        }
        return environment
    }
}

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment = .mock
}
