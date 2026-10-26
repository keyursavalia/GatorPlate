import Foundation

/// The current user's profile plus the Auth-level email verification flag. Guests are Firebase anonymous users.
nonisolated struct AuthSession: Sendable {
    var profile: UserProfile
    var isEmailVerified: Bool

    var isGuest: Bool { profile.isGuest }

    /// Posting needs an account (and a verified email when `AppConfig.requireEmailVerification`).
    var canPost: Bool {
        !isGuest && (isEmailVerified || !AppConfig.requireEmailVerification)
    }

    /// Signed up but the email isn't verified yet.
    var needsVerification: Bool { !isGuest && !canPost }
}
