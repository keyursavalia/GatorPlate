import FirebaseAppCheck
import FirebaseCore
import OSLog
import SwiftUI

@main
struct GatorPlateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment: AppEnvironment

    init() {
        if ProcessInfo.processInfo.arguments.contains(AppConfig.uiTestMockArgument) {
            environment = .mock
        } else {
            Self.configureFirebase()
            environment = .live(firebaseConfigured: FirebaseApp.app() != nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, environment)
        }
    }

    /// App Check must be set up BEFORE `FirebaseApp.configure()`.
    private static func configureFirebase() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif

        FirebaseApp.configure()
        Logger.firebase.info("Firebase configured")
    }
}
