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

    /// The inline message for an email field, or nil when it's fine (Sign in, Create account, Forgot password).
    static func emailMessage(_ raw: String) -> String? {
        if raw.trimmingCharacters(in: .whitespaces).isEmpty { return "Email is required." }
        switch emailIssue(raw) {
        case .invalidFormat: return "Enter a valid email address."
        case .domainNotAllowed:
            return "Use an email ending in \(AppConfig.allowedEmailDomains.joined(separator: ", "))."
        case nil: return nil
        }
    }

    /// New passwords (Create account, Change password) meet every `PasswordRule`. Sign-in never checks them, so
    /// older passwords keep working.
    static func isPasswordValid(_ password: String) -> Bool {
        PasswordRule.allCases.allSatisfy { $0.isMet(by: password) }
    }

    /// A new password that misses a rule (from the app or Firebase's policy).
    static let weakPasswordMessage = "Use at least \(AppConfig.minPasswordLength) characters with an uppercase letter, "
        + "a lowercase letter, a number and a symbol."

    static func trimmedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// One requirement for a new password, shown as a live checklist (`PasswordChecklist`). Mirrors the Firebase Auth
/// password policy (Authentication > Settings > Password policy), which enforces the same rules on the server.
nonisolated enum PasswordRule: CaseIterable, Sendable {
    case length, uppercase, lowercase, number, symbol

    /// The special characters Firebase's password policy counts as non-alphanumeric.
    static let symbols = Set("^$*.[]{}()?\"!@#%&/\\,><':;|_~")

    var text: String {
        switch self {
        case .length: "At least \(AppConfig.minPasswordLength) characters"
        case .uppercase: "An uppercase letter"
        case .lowercase: "A lowercase letter"
        case .number: "A number"
        case .symbol: "A symbol, like ! # or ?"
        }
    }

    func isMet(by password: String) -> Bool {
        switch self {
        case .length: password.count >= AppConfig.minPasswordLength
        case .uppercase: password.contains { $0.isASCII && $0.isUppercase }
        case .lowercase: password.contains { $0.isASCII && $0.isLowercase }
        case .number: password.contains { $0.isASCII && $0.isNumber }
        case .symbol: password.contains(where: Self.symbols.contains)
        }
    }
}
