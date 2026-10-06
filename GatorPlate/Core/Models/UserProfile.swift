import Foundation

nonisolated struct UserProfile: Codable, Sendable {
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
}
