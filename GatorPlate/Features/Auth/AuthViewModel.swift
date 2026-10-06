import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AuthViewModel {
    enum Mode { case logIn, signUp }

    // MARK: State
    private(set) var state: AuthState = .loading
    private(set) var isSubmitting = false
    /// Failure from the last submit/accept/verify action. Shown inline; does not change `state`.
    private(set) var formError: String?
    private(set) var infoMessage: String?

    // MARK: Form
    var mode: Mode = .logIn
    var accountType: AccountType = .student
    var name = ""
    var orgName = ""
    var email = ""
    var password = ""
    private var hasAttemptedSubmit = false

    @ObservationIgnored private let auth: any AuthService
    @ObservationIgnored private var listenTask: Task<Void, Never>?

    init(auth: any AuthService) {
        self.auth = auth
    }

    // MARK: Session

    /// Starts observing the session. Safe to call more than once.
    func start() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            guard let stream = self?.auth.currentUser else { return }
            for await result in stream {
                self?.apply(result)
            }
        }
    }

    private func apply(_ result: Result<AuthSession?, AppError>) {
        switch result {
        case .failure(let error):
            state = .error(error.userMessage)
        case .success(nil):
            state = .signedOut
            resetTransientInput()
        case .success(let session?):
            if AppConfig.requireEmailVerification && !session.isEmailVerified {
                state = .needsVerification(session.profile)
            } else if session.profile.acceptedTermsVersion != AppConfig.termsVersion {
                state = .needsTerms(session.profile)
            } else {
                state = .signedIn(session.profile)
            }
            password = ""
        }
    }

    private func resetTransientInput() {
        password = ""
        formError = nil
        infoMessage = nil
        hasAttemptedSubmit = false
    }

    // MARK: Actions

    func toggleMode() {
        mode = mode == .logIn ? .signUp : .logIn
        formError = nil
        hasAttemptedSubmit = false
    }

    func submit() async {
        hasAttemptedSubmit = true
        formError = nil
        guard isFormValid else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let normalizedEmail = Validation.normalizedEmail(email)
        do {
            switch mode {
            case .logIn:
                try await auth.signIn(email: normalizedEmail, password: password)
            case .signUp:
                let isOrg = accountType == .organization
                let org = Validation.trimmedName(orgName)
                let displayName = isOrg ? org : Validation.trimmedName(name)
                try await auth.signUp(email: normalizedEmail, password: password, displayName: displayName,
                                      accountType: accountType, orgName: isOrg ? org : nil)
            }
        } catch {
            formError = message(for: error)
        }
    }

    func acceptTerms() async {
        formError = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.acceptTerms(version: AppConfig.termsVersion)
        } catch {
            formError = message(for: error)
        }
    }

    func sendVerificationEmail() async {
        formError = nil
        infoMessage = nil
        do {
            try await auth.sendVerificationEmail()
            infoMessage = "Verification email sent. Check your inbox and spam folder."
        } catch {
            formError = message(for: error)
        }
    }

    func refreshVerification() async {
        formError = nil
        infoMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.refreshSession()
            infoMessage = "Not verified yet. Tap the link in the email, then try again."
        } catch {
            formError = message(for: error)
        }
    }

    func retry() async {
        state = .loading
        do {
            try await auth.refreshSession()
        } catch {
            state = .error(message(for: error))
        }
    }

    func signOut() {
        do {
            try auth.signOut()
        } catch {
            Logger.ui.error("Sign out failed")
            formError = message(for: error)
        }
    }

    // MARK: Validation (inline messages appear after the first submit attempt)

    var nameError: String? {
        guard hasAttemptedSubmit, mode == .signUp else { return nil }
        let value = accountType == .organization ? orgName : name
        guard Validation.trimmedName(value).isEmpty else { return nil }
        return accountType == .organization ? "Enter your organization's name." : "Enter your name."
    }

    var emailError: String? {
        guard hasAttemptedSubmit else { return nil }
        switch Validation.emailIssue(email) {
        case .invalidFormat: return "Enter a valid email address."
        case .domainNotAllowed:
            return "Use an email ending in \(AppConfig.allowedEmailDomains.joined(separator: ", "))."
        case nil: return nil
        }
    }

    var passwordError: String? {
        guard hasAttemptedSubmit else { return nil }
        if mode == .signUp {
            return Validation.isPasswordValid(password) ? nil : "Use at least \(AppConfig.minPasswordLength) characters."
        }
        return password.isEmpty ? "Enter your password." : nil
    }

    private var isFormValid: Bool {
        nameError == nil && emailError == nil && passwordError == nil
    }

    private func message(for error: Error) -> String {
        (error as? AppError ?? .unknown).userMessage
    }
}
