import Foundation

nonisolated enum AccountType: String, Codable, Sendable {
    case student, organization
    /// Browsing without an account (Firebase anonymous user). Can't post; can get alerts and report.
    case guest

    var displayName: String {
        switch self {
        case .student: "Student"
        case .organization: "Student organization"
        case .guest: "Guest"
        }
    }
}
