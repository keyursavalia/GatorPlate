import Foundation

/// Account management (App Store Guideline 5.1.1(v): accounts made in the app can be deleted in the app).
@MainActor
protocol AccountService {
    /// Display name and, for organizations, the org name. Applies to new posts only (rules match a post's
    /// `authorName` to the profile when it's created).
    func updateProfile(displayName: String, orgName: String?) async throws
    /// Reauthenticates with the current password, then sets the new one.
    func changePassword(current: String, new: String) async throws
    /// Never reveals whether an account exists: callers always show the same message. Throws only `.network` and
    /// `.validation(AccountMessages.resetRateLimited)`.
    func sendPasswordReset(email: String) async throws
    /// Account > Change password > "Forgot your current password?": the link goes to the signed-in account's email.
    func sendPasswordResetToCurrentUser() async throws
    /// Reauthenticates, refreshes the ID token (so the server sees a recent sign-in), runs `prepare` (stop the
    /// session), calls the `deleteAccount` function, then signs out locally. A wrong password throws
    /// `.unauthorized`; on any error the user stays signed in.
    func deleteAccount(password: String, prepare: () async -> Void) async throws
}

/// Messages shared by the account screens.
nonisolated enum AccountMessages {
    static let wrongPassword = "That password isn't right."
    static let resetRateLimited = "Too many tries. Wait a few minutes and try again."
    static let signedOut = "You were signed out. Sign in again."

    /// The same words whether or not the account exists.
    static func resetSent(to email: String) -> String {
        "If an account exists for \(email), we sent a link to reset your password."
    }
    static let deleted = "Your account was deleted."
}
