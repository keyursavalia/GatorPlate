import Foundation

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var uid: String
    var displayName: String
    var email: String
    var accountType: AccountType
    var orgName: String?
    var acceptedTermsVersion: String
    var acceptedTermsAt: Date
    var notificationsEnabled: Bool
    var createdAt: Date
}
