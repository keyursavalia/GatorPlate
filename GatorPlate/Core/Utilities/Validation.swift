import Foundation

nonisolated enum Validation {
    enum EmailIssue {
        case invalidFormat
        case domainNotAllowed
    }

    /// Trims whitespace and lowercases.
    static func normalizedEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func emailIssue(_ raw: String) -> EmailIssue? {
        let email = normalizedEmail(raw)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard email.count <= AppConfig.maxEmailLength,
              parts.count == 2,
              !parts[0].isEmpty,
              !email.contains(where: \.isWhitespace) else { return .invalidFormat }
        return AppConfig.allowedEmailDomains.contains(String(parts[1])) ? nil : .domainNotAllowed
    }

    static func isPasswordValid(_ password: String) -> Bool {
        password.count >= AppConfig.minPasswordLength
    }

    static func trimmedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
