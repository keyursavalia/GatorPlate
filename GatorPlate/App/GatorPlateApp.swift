import FirebaseAppCheck
import FirebaseCore
import OSLog
import SwiftUI

@main
struct GatorPlateApp: App {
    init() {
        Self.configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, .live)
        }
    }

    /// App Check must be installed BEFORE `FirebaseApp.configure()`.
    private static func configureFirebase() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestFactory())
        #endif
        FirebaseApp.configure()
        Logger.app.info("Firebase configured")
    }
}
