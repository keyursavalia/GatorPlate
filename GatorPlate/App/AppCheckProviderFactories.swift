import FirebaseAppCheck
import FirebaseCore

/// Release builds attest with App Attest. Debug builds use `AppCheckDebugProviderFactory`
/// (see `GatorPlateApp`), which prints a debug token to the console on first run.
nonisolated final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        AppAttestProvider(app: app)
    }
}
