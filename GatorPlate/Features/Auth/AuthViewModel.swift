import Foundation
import Observation
import OSLog

/// Entry flow and the sign-in / create-account forms. First launch: Terms gate, then a guest session.
/// An account is asked for only when the user wants to post (`AccountFlowView`).
@MainActor
@Observable
final class AuthViewModel {
    enum Mode { case logIn, signUp }

    // MARK: State
    private(set) var state: AuthState = .loading
    private(set) var isSubmitting = false
    /// Failure from the last submit/verify action. Shown inline; does not change `state`.
    private(set) var formError: String?
    private(set) var infoMessage: String?
    /// One-time notice for the main UI, e.g. "Your account was deleted." after deletion.
    private(set) var notice: String?
    /// "Forgot password?" result; the same text whether or not the account exists.
    private(set) var resetMessage: String?

    // MARK: Form
    var mode: Mode = .logIn
    var accountType: AccountType = .student
    var name = ""
    var orgName = ""
    var email = ""
    var password = ""
    private var hasAttemptedSubmit = false

    @ObservationIgnored private let auth: any AuthService
    @ObservationIgnored private let account: any AccountService
    @ObservationIgnored private let terms: TermsAcceptance
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var isStartingGuest = false
    /// Profiles whose Terms version was already brought up to date this launch.
    @ObservationIgnored private var termsRecordedFor: Set<String> = []

    init(auth: any AuthService, account: any AccountService, terms: TermsAcceptance = TermsAcceptance()) {
        self.auth = auth
        self.account = account
        self.terms = terms
    }

    var session: AuthSession? {
        if case .ready(let session) = state { session } else { nil }
    }

    // MARK: Session

    /// Shows the Terms gate if needed, otherwise starts observing the session. Safe to call more than once.
    func start() {
        guard listenTask == nil else { return }
        guard terms.isCurrent else {
            state = .needsTerms
            return
        }
        listenTask = Task { [weak self] in
            guard let stream = self?.auth.currentUser else { return }
            for await result in stream {
                self?.apply(result)
            }
        }
    }

    /// "Agree & continue" on the Terms gate.
    func acceptTermsGate() {
        terms.recordCurrent()
        state = .loading
        if listenTask == nil {
            start()
        } else {
            // Already listening: re-emit the session so it's applied with the Terms accepted.
            Task { await retry() }
        }
    }

    private func apply(_ result: Result<AuthSession?, AppError>) {
        switch result {
        case .failure(let error):
            state = .error(error.userMessage)
        case .success(nil):
            // Signed out or first launch: browse as a guest.
            state = .loading
            resetTransientInput()
            Task { await startGuest() }
        case .success(let session?):
            guard terms.isCurrent else {
                state = .needsTerms
                return
            }
            recordTermsIfNeeded(for: session.profile)
            state = .ready(session)
            password = ""
        }
    }

    private func startGuest() async {
        guard !isStartingGuest else { return }
        isStartingGuest = true
        defer { isStartingGuest = false }
        do {
            try await auth.signInAsGuest(acceptedTermsVersion: AppConfig.termsVersion,
                                         acceptedTermsAt: terms.acceptedAt ?? .now)
        } catch {
            Logger.ui.error("Guest session failed to start")
            state = .error(message(for: error))
        }
    }

    /// The Terms were accepted on this device; the profile records the same version (best effort).
    private func recordTermsIfNeeded(for profile: UserProfile) {
        guard profile.acceptedTermsVersion != AppConfig.termsVersion,
              !termsRecordedFor.contains(profile.uid) else { return }
        termsRecordedFor.insert(profile.uid)
        Task {
            do {
                try await auth.acceptTerms(version: AppConfig.termsVersion)
            } catch {
                Logger.ui.error("Couldn't record the Terms version on the profile")
            }
        }
    }

    private func resetTransientInput() {
        password = ""
        formError = nil
        infoMessage = nil
        hasAttemptedSubmit = false
    }

    // MARK: Actions

    func setMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        formError = nil
        hasAttemptedSubmit = false
    }

    /// Signing in replaces a guest session, so `prepareSwitch` first removes the guest's alert registration;
    /// `restore` restarts the guest session if sign-in fails.
    func submit(prepareSwitch: () async -> Void = {}, restore: () -> Void = {}) async {
        hasAttemptedSubmit = true
        formError = nil
        guard isFormValid else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let normalizedEmail = Validation.normalizedEmail(email)
        switch mode {
        case .logIn:
            let replacesGuest = session?.isGuest == true
            if replacesGuest { await prepareSwitch() }
            do {
                try await auth.signIn(email: normalizedEmail, password: password)
            } catch {
                if replacesGuest { restore() }
                formError = message(for: error)
            }
        case .signUp:
            let isOrg = accountType == .organization
            let org = Validation.trimmedName(orgName)
            let displayName = isOrg ? org : Validation.trimmedName(name)
            do {
                try await auth.signUp(email: normalizedEmail, password: password, displayName: displayName,
                                      accountType: accountType, orgName: isOrg ? org : nil)
            } catch {
                formError = message(for: error)
            }
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
            if session?.canPost != true {
                infoMessage = "Not verified yet. Tap the link in the email, then try again."
            }
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

    /// Sends a reset link. Always shows the same message so nobody can learn whether an email has an account.
    func sendPasswordReset(email rawEmail: String) async {
        resetMessage = nil
        let email = Validation.normalizedEmail(rawEmail)
        guard Validation.emailIssue(email) == nil else {
            resetMessage = "Enter the email you signed up with."
            return
        }
        do {
            try await account.sendPasswordReset(email: email)
        } catch AppError.network {
            resetMessage = AppError.network.userMessage
            return
        } catch {
            Logger.ui.error("Password reset request failed")
        }
        resetMessage = AccountMessages.resetSent
    }

    func clearResetMessage() {
        resetMessage = nil
    }

    func clearFormMessages() {
        formError = nil
        infoMessage = nil
        hasAttemptedSubmit = false
    }

    /// The server already deleted the account; the app signs out and continues as a guest.
    func accountWasDeleted() {
        notice = AccountMessages.deleted
        signOut()
    }

    func consumeNotice() -> String? {
        defer { notice = nil }
        return notice
    }

    /// From the error screen: drop whatever session is stored and start a fresh guest session.
    func startOver() {
        signOut()
        Task { await retry() }
    }

    /// Back to browsing as a guest.
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
        return accountType == .organization ? "Organization name is required." : "Name is required."
    }

    var emailError: String? {
        guard hasAttemptedSubmit else { return nil }
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return "Email is required." }
        switch Validation.emailIssue(email) {
        case .invalidFormat: return "Enter a valid email address."
        case .domainNotAllowed:
            return "Use an email ending in \(AppConfig.allowedEmailDomains.joined(separator: ", "))."
        case nil: return nil
        }
    }

    var passwordError: String? {
        guard hasAttemptedSubmit else { return nil }
        if password.isEmpty { return "Password is required." }
        if mode == .signUp, !Validation.isPasswordValid(password) {
            return "Use at least \(AppConfig.minPasswordLength) characters."
        }
        return nil
    }

    private var isFormValid: Bool {
        nameError == nil && emailError == nil && passwordError == nil
    }

    private func message(for error: Error) -> String {
        (error as? AppError ?? .unknown).userMessage
    }
}
