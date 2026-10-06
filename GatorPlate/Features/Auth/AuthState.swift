import Foundation

/// Where the user is in the sign-in journey. Only `AuthViewModel` changes it, driven by `AuthService.currentUser`.
enum AuthState {
    /// Checking the stored session.
    case loading
    case signedOut
    /// Signed in, but the email isn't verified yet (only when `AppConfig.requireEmailVerification`).
    case needsVerification(UserProfile)
    /// Signed in, but the current Terms version isn't accepted.
    case needsTerms(UserProfile)
    case signedIn(UserProfile)
    /// The session exists but couldn't be loaded. Offers Retry and Sign out.
    case error(String)
}
