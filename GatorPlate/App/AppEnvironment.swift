import SwiftUI

/// Dependency container. View models receive protocols from here, never concrete services.
struct AppEnvironment {
    var auth: any AuthService
    var posts: any PostService
    var analyzer: any FoodAnalyzing
    var location: any LocationProviding
    var images: any ImageStore

    static var live: AppEnvironment {
        AppEnvironment(auth: FirebaseAuthService(), posts: FirestorePostService(),
                       analyzer: GeminiFoodAnalyzer(), location: CoreLocationProvider(),
                       images: FirestoreImageStore())
    }

    static var mock: AppEnvironment {
        AppEnvironment(auth: MockAuthService(), posts: MockPostService(),
                       analyzer: MockFoodAnalyzer(), location: MockLocationProvider(),
                       images: MockImageStore())
    }
}

extension EnvironmentValues {
    /// Defaults to mocks so previews work; the app injects `.live`.
    @Entry var appEnvironment: AppEnvironment = .mock
}
