import Foundation

nonisolated enum AuthField: Hashable, Sendable {
    case email, password, name, orgName

    /// Top-to-bottom order on the Welcome screen; used for focus and first-error lookup.
    static let displayOrder: [AuthField] = [.email, .password, .name, .orgName]
}

nonisolated enum AuthMode: Equatable, Sendable {
    case logIn
    case signUp
}

/// User-facing copy for auth validation and service errors. Never shows raw error strings.
nonisolated enum AuthMessages {
    static let invalidEmail = "Use your SFSU email (ends in @sfsu.edu or @mail.sfsu.edu)."
    static let weakPassword = "Use at least 8 characters."
    static let missingPassword = "Enter your password."
    static let missingName = "Enter your name."
    static let missingOrgName = "Enter your organization's name."
    static let emailInUse = "That email already has an account. Try logging in."
    static let invalidCredentials = "Email or password is incorrect."
    static let network = "No connection. Check your internet and try again."
    static let generic = "Something went wrong. Please try again."

    static func message(for error: AppError) -> String {
        switch error {
        case .emailInUse: emailInUse
        case .invalidCredentials: invalidCredentials
        case .weakPassword: weakPassword
        case .network: network
        case .permissionDenied, .unauthorized, .aiUnavailable, .validation, .unknown: generic
        }
    }
}

nonisolated enum AuthValidation {
    /// Trimmed and lowercased, the form used for validation and sent to the service.
    static func normalizedEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Exactly one `@`, a non-empty local part without whitespace, and a domain that is exactly
    /// one of `AppConfig.allowedEmailDomains`. Suffix tricks like `x@sfsu.edu.evil.com` fail.
    static func isValidSFSUEmail(_ raw: String) -> Bool {
        let email = normalizedEmail(raw)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = String(parts[1])
        guard !local.isEmpty, local.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        return AppConfig.allowedEmailDomains.contains(domain)
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= AppConfig.minPasswordLength
    }
}

/// Raw form input plus pure validation. No service calls happen unless `validate` returns no errors.
nonisolated struct AuthFormInput: Equatable, Sendable {
    var email = ""
    var password = ""
    var name = ""
    var orgName = ""
    var accountType: AccountType = .student

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOrgName: String { orgName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Public poster name: the typed name for Student, the org name for Organization.
    var displayName: String {
        accountType == .organization ? trimmedOrgName : trimmedName
    }

    /// Nil for Student so no org name is stored.
    var resolvedOrgName: String? {
        accountType == .organization ? trimmedOrgName : nil
    }

    func validate(mode: AuthMode) -> [AuthField: String] {
        var errors: [AuthField: String] = [:]

        if !AuthValidation.isValidSFSUEmail(email) {
            errors[.email] = AuthMessages.invalidEmail
        }

        switch mode {
        case .logIn:
            if password.isEmpty { errors[.password] = AuthMessages.missingPassword }
        case .signUp:
            if !AuthValidation.isValidPassword(password) { errors[.password] = AuthMessages.weakPassword }
            switch accountType {
            case .student:
                if trimmedName.isEmpty || trimmedName.count > AppConfig.maxDisplayNameLength {
                    errors[.name] = AuthMessages.missingName
                }
            case .organization:
                if trimmedOrgName.isEmpty || trimmedOrgName.count > AppConfig.maxOrgNameLength {
                    errors[.orgName] = AuthMessages.missingOrgName
                }
            }
        }
        return errors
    }
}
