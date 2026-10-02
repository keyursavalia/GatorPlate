import Foundation
import Observation
import OSLog

nonisolated enum AuthSessionState: Equatable, Sendable {
    /// Checking the persisted session.
    case loading
    case signedOut
    /// Profile exists but the current terms version has not been accepted.
    case needsTerms(UserProfile)
    case signedIn(UserProfile)
    /// Session-level failure (could not restore session or load profile). Offers Retry.
    case error(String)
}

@MainActor
@Observable
final class AuthViewModel {
    private(set) var state: AuthSessionState

    // Form
    var mode: AuthMode = .logIn {
        didSet {
            guard mode != oldValue else { return }
            fieldErrors = [:]
            submitError = nil
        }
    }
    var email = "" { didSet { fieldErrors[.email] = nil } }
    var password = "" { didSet { fieldErrors[.password] = nil } }
    var name = "" { didSet { fieldErrors[.name] = nil } }
    var orgName = "" { didSet { fieldErrors[.orgName] = nil } }
    var accountType: AccountType = .student {
        didSet {
            fieldErrors[.name] = nil
            fieldErrors[.orgName] = nil
        }
    }
    private(set) var fieldErrors: [AuthField: String] = [:]
    private(set) var submitError: String?
    private(set) var isSubmitting = false
    /// Incremented on every submit that fails validation; views use it to move focus and announce errors.
    private(set) var validationFailureCount = 0

    // Terms
    var hasAgreedToTerms = false
    private(set) var termsError: String?
    private(set) var isAcceptingTerms = false

    // Sign out
    private(set) var signOutError: String?

    /// Bumped by `retry()`; the root view restarts `start()` when it changes.
    private(set) var sessionAttempt = 0

    private let auth: any AuthService
    private let termsVersion: String

    init(auth: any AuthService, termsVersion: String = AppConfig.termsVersion, initialState: AuthSessionState = .loading) {
        self.auth = auth
        self.termsVersion = termsVersion
        self.state = initialState
    }

    var formInput: AuthFormInput {
        AuthFormInput(email: email, password: password, name: name, orgName: orgName, accountType: accountType)
    }

    var firstInvalidField: AuthField? {
        AuthField.displayOrder.first { fieldErrors[$0] != nil }
    }

    // MARK: - Session

    /// Consumes the session stream until it finishes or fails. Call from `.task(id: sessionAttempt)`.
    func start() async {
        state = .loading
        do {
            for try await profile in auth.observeCurrentUser() {
                apply(sessionProfile: profile)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !isSubmitting else { return }
            Logger.app.error("Session stream failed")
            state = .error(AuthMessages.generic)
        }
    }

    func retry() {
        sessionAttempt += 1
    }

    private func apply(sessionProfile profile: UserProfile?) {
        // Submit results are authoritative while a request is in flight.
        guard !isSubmitting else { return }

        guard let profile else {
            if state != .signedOut { resetToSignedOut() }
            return
        }
        // After the first load this view model owns profile state; ignore echoes of our own writes
        // so a late sign-up emission cannot regress `.signedIn` back to `.needsTerms`.
        switch state {
        case .needsTerms(let known), .signedIn(let known):
            if known.uid == profile.uid { return }
        case .loading, .signedOut, .error:
            break
        }
        state = resolve(profile)
    }

    private func resolve(_ profile: UserProfile) -> AuthSessionState {
        profile.needsTermsAcceptance(currentVersion: termsVersion) ? .needsTerms(profile) : .signedIn(profile)
    }

    // MARK: - Submit

    func submit() async {
        guard !isSubmitting else { return }
        submitError = nil

        let input = formInput
        let errors = input.validate(mode: mode)
        fieldErrors = errors
        guard errors.isEmpty else {
            validationFailureCount += 1
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let normalizedEmail = AuthValidation.normalizedEmail(input.email)
            let profile: UserProfile
            switch mode {
            case .signUp:
                profile = try await auth.signUp(
                    email: normalizedEmail,
                    password: input.password,
                    displayName: input.displayName,
                    accountType: input.accountType,
                    orgName: input.resolvedOrgName
                )
            case .logIn:
                profile = try await auth.signIn(email: normalizedEmail, password: input.password)
            }
            password = ""
            hasAgreedToTerms = false
            termsError = nil
            state = resolve(profile)
        } catch let error as AppError {
            submitError = AuthMessages.message(for: error)
        } catch {
            submitError = AuthMessages.generic
        }
    }

    // MARK: - Terms

    func acceptTerms() async {
        guard case .needsTerms = state, hasAgreedToTerms, !isAcceptingTerms else { return }
        isAcceptingTerms = true
        termsError = nil
        defer { isAcceptingTerms = false }

        do {
            let profile = try await auth.acceptTerms(version: termsVersion)
            state = .signedIn(profile)
        } catch let error as AppError {
            termsError = AuthMessages.message(for: error)
        } catch {
            termsError = AuthMessages.generic
        }
    }

    func declineTerms() async {
        await signOut()
    }

    // MARK: - Sign out

    func signOut() async {
        signOutError = nil
        do {
            try await auth.signOut()
            resetToSignedOut()
        } catch {
            Logger.app.error("Sign out failed")
            signOutError = AuthMessages.generic
        }
    }

    private func resetToSignedOut() {
        email = ""
        password = ""
        name = ""
        orgName = ""
        accountType = .student
        mode = .logIn
        fieldErrors = [:]
        submitError = nil
        hasAgreedToTerms = false
        termsError = nil
        state = .signedOut
    }
}
