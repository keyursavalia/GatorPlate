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
        // Cached or default values apply at once; the fetch and realtime listener never block launch.
        environment.runtime.start()
        let runtime = environment.runtime
        _authViewModel = State(initialValue: AuthViewModel(auth: environment.auth, account: environment.account,
                                                           nameFilter: { runtime.current.contentFilter }))
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
