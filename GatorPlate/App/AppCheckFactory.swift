import FirebaseAppCheck
import FirebaseCore

/// Release provider factory: App Attest.
final class AppAttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        AppAttestProvider(app: app)
    }
}
