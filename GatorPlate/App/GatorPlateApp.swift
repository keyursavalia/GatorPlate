import FirebaseAppCheck
import FirebaseCore
import OSLog
import SwiftUI

@main
struct GatorPlateApp: App {
    /// APNs token for Firebase Messaging.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment: AppEnvironment
    @State private var authViewModel: AuthViewModel

    init() {
        Self.configureFirebase()
        // Built after configure so no Firebase service is touched before App Check is installed.
        let environment = AppEnvironment.live
        self.environment = environment
        _authViewModel = State(initialValue: AuthViewModel(auth: environment.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: authViewModel)
                .environment(\.appEnvironment, environment)
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
