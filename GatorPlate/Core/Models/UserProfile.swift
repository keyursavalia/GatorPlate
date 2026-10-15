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
    /// Mutes alerts 11 PM - 7 AM campus time (checked by the Cloud Function). Nil until set.
    var quietHoursEnabled: Bool?
    /// Nil until the user saves filters; nil means all free food.
    var alertFilters: AlertFilters?
    var createdAt: Date
}
