import Foundation

/// Where the app is in its entry flow. Only `AuthViewModel` changes it, driven by the device's Terms acceptance
/// and `AuthService.currentUser`. Nobody has to sign in to browse: after the Terms, a guest session starts.
enum AuthState {
    /// Checking the stored session or starting a guest session.
    case loading
    /// The current Terms version isn't accepted on this device (first launch or a new version).
    case needsTerms
    /// A guest or an account. Posting needs `AuthSession.canPost`.
    case ready(AuthSession)
    /// The session couldn't be started or loaded. Offers Retry.
    case error(String)
}
