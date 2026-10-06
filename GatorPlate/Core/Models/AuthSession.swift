import Foundation

/// A signed-in user's profile plus the Auth-level email verification flag.
nonisolated struct AuthSession: Sendable {
    var profile: UserProfile
    var isEmailVerified: Bool
}
