import Foundation

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var uid: String
    var displayName: String
    var email: String
    var accountType: AccountType
    var orgName: String?
    /// Nil until the user accepts the Terms of Use.
    var acceptedTermsVersion: String?
    var acceptedTermsAt: Date?
    var notificationsEnabled: Bool
    var createdAt: Date

    /// True when the user has not accepted the given terms version (never, or an older one).
    func needsTermsAcceptance(currentVersion: String) -> Bool {
        acceptedTermsVersion != currentVersion
    }
}
