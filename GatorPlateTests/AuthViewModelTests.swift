import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct AuthViewModelTests {
    private func staleTermsProfile() -> UserProfile {
        var profile = SampleData.profile
        profile.acceptedTermsVersion = "old-version"
        return profile
    }

    private func unacceptedProfile() -> UserProfile {
        var profile = SampleData.profile
        profile.acceptedTermsVersion = nil
        profile.acceptedTermsAt = nil
        return profile
    }

    private func makeViewModel(
        _ auth: MockAuthService = MockAuthService(keepsStreamOpen: false),
        state: AuthSessionState = .signedOut
    ) -> AuthViewModel {
        AuthViewModel(auth: auth, initialState: state)
    }

    private func fillSignUp(_ viewModel: AuthViewModel, type: AccountType = .student) {
        viewModel.mode = .signUp
        viewModel.email = "  Ada@Mail.SFSU.edu "
        viewModel.password = "password1"
        viewModel.accountType = type
        viewModel.name = "Ada"
        viewModel.orgName = "Gator Cooking Club"
    }

    // MARK: - Session restore

    @Test func startsInLoadingState() {
        let viewModel = AuthViewModel(auth: MockAuthService())
        #expect(viewModel.state == .loading)
    }

    @Test func noSessionGoesToSignedOut() async {
        let viewModel = AuthViewModel(auth: MockAuthService(keepsStreamOpen: false))
        await viewModel.start()
        #expect(viewModel.state == .signedOut)
    }

    @Test func sessionWithCurrentTermsGoesToSignedIn() async {
        let auth = MockAuthService(signedInAs: SampleData.profile, keepsStreamOpen: false)
        let viewModel = AuthViewModel(auth: auth)
        await viewModel.start()
        #expect(viewModel.state == .signedIn(SampleData.profile))
    }

    @Test func sessionWithoutTermsGoesToNeedsTerms() async {
        let profile = unacceptedProfile()
        let viewModel = AuthViewModel(auth: MockAuthService(signedInAs: profile, keepsStreamOpen: false))
        await viewModel.start()
        #expect(viewModel.state == .needsTerms(profile))
    }

    @Test func sessionWithStaleTermsVersionGoesToNeedsTerms() async {
        let profile = staleTermsProfile()
        let viewModel = AuthViewModel(auth: MockAuthService(signedInAs: profile, keepsStreamOpen: false))
        await viewModel.start()
        #expect(viewModel.state == .needsTerms(profile))
    }

    @Test func streamFailureGoesToErrorAndRetryRecovers() async {
        let auth = MockAuthService(failures: .init(session: .network), keepsStreamOpen: false)
        let viewModel = AuthViewModel(auth: auth)
        await viewModel.start()
        #expect(viewModel.state == .error(AuthMessages.generic))

        await auth.setFailures(.init())
        viewModel.retry()
        #expect(viewModel.sessionAttempt == 1)
        await viewModel.start()
        #expect(viewModel.state == .signedOut)
    }

    // MARK: - Submit

    @Test func invalidFormMakesNoServiceCallAndSetsFieldErrors() async {
        // A network failure is armed; if the service were called it would show up as submitError.
        let auth = MockAuthService(failures: .init(signUp: .network, signIn: .network))
        let viewModel = makeViewModel(auth)
        viewModel.email = "test@gmail.com"
        viewModel.password = "password1"

        await viewModel.submit()

        #expect(viewModel.fieldErrors[.email] == AuthMessages.invalidEmail)
        #expect(viewModel.submitError == nil)
        #expect(viewModel.state == .signedOut)
        #expect(viewModel.validationFailureCount == 1)
        #expect(viewModel.firstInvalidField == .email)
    }

    @Test func editingAFieldClearsItsError() async {
        let viewModel = makeViewModel()
        viewModel.email = "bad"
        await viewModel.submit()
        #expect(viewModel.fieldErrors[.email] != nil)
        viewModel.email = "ada@sfsu.edu"
        #expect(viewModel.fieldErrors[.email] == nil)
    }

    @Test func studentSignUpNormalizesEmailAndGoesToNeedsTerms() async {
        let viewModel = makeViewModel()
        fillSignUp(viewModel)
        await viewModel.submit()

        guard case .needsTerms(let profile) = viewModel.state else {
            Issue.record("expected .needsTerms, got \(viewModel.state)")
            return
        }
        #expect(profile.email == "ada@mail.sfsu.edu")
        #expect(profile.displayName == "Ada")
        #expect(profile.accountType == .student)
        #expect(profile.orgName == nil)
        #expect(viewModel.password.isEmpty)
    }

    @Test func organizationSignUpUsesOrgNameAsPosterName() async {
        let viewModel = makeViewModel()
        fillSignUp(viewModel, type: .organization)
        await viewModel.submit()

        guard case .needsTerms(let profile) = viewModel.state else {
            Issue.record("expected .needsTerms, got \(viewModel.state)")
            return
        }
        #expect(profile.accountType == .organization)
        #expect(profile.displayName == "Gator Cooking Club")
        #expect(profile.orgName == "Gator Cooking Club")
    }

    @Test func organizationWithoutOrgNameIsBlocked() async {
        let viewModel = makeViewModel()
        fillSignUp(viewModel, type: .organization)
        viewModel.orgName = " "
        await viewModel.submit()
        #expect(viewModel.fieldErrors[.orgName] == AuthMessages.missingOrgName)
        #expect(viewModel.state == .signedOut)
    }

    @Test func logInWithCurrentTermsSkipsTermsStep() async throws {
        let auth = MockAuthService(signedInAs: SampleData.profile, keepsStreamOpen: false)
        try await auth.signOut()
        let viewModel = makeViewModel(auth)
        viewModel.email = SampleData.profile.email
        viewModel.password = "password1"

        await viewModel.submit()
        #expect(viewModel.state == .signedIn(SampleData.profile))
    }

    @Test func logInWithStaleTermsReprompts() async throws {
        let profile = staleTermsProfile()
        let auth = MockAuthService(signedInAs: profile, keepsStreamOpen: false)
        try await auth.signOut()
        let viewModel = makeViewModel(auth)
        viewModel.email = profile.email
        viewModel.password = "password1"

        await viewModel.submit()
        #expect(viewModel.state == .needsTerms(profile))
    }

    @Test(arguments: [
        (AppError.emailInUse, AuthMessages.emailInUse),
        (AppError.invalidCredentials, AuthMessages.invalidCredentials),
        (AppError.network, AuthMessages.network),
        (AppError.unknown, AuthMessages.generic)
    ])
    func serviceErrorsShowFriendlyBannerAndStayOnForm(error: AppError, message: String) async {
        let auth = MockAuthService(failures: .init(signIn: error))
        let viewModel = makeViewModel(auth)
        viewModel.email = "ada@sfsu.edu"
        viewModel.password = "password1"

        await viewModel.submit()

        #expect(viewModel.submitError == message)
        #expect(viewModel.state == .signedOut)
        #expect(viewModel.email == "ada@sfsu.edu", "form input is kept so the user can retry")
        #expect(!viewModel.isSubmitting)
    }

    @Test func duplicateSignUpShowsEmailInUse() async throws {
        let auth = MockAuthService()
        _ = try await auth.signUp(
            email: "ada@mail.sfsu.edu", password: "password1",
            displayName: "Ada", accountType: .student, orgName: nil
        )
        let viewModel = makeViewModel(auth)
        fillSignUp(viewModel)
        await viewModel.submit()
        #expect(viewModel.submitError == AuthMessages.emailInUse)
    }

    @Test func switchingModeKeepsEmailAndClearsErrors() async {
        let viewModel = makeViewModel()
        viewModel.email = "bad"
        await viewModel.submit()
        #expect(!viewModel.fieldErrors.isEmpty)

        viewModel.mode = .signUp
        #expect(viewModel.fieldErrors.isEmpty)
        #expect(viewModel.submitError == nil)
        #expect(viewModel.email == "bad")
    }

    // MARK: - Terms

    @Test func acceptingTermsStoresVersionAndTimestampAndSignsIn() async {
        let viewModel = makeViewModel()
        fillSignUp(viewModel)
        await viewModel.submit()

        viewModel.hasAgreedToTerms = true
        await viewModel.acceptTerms()

        guard case .signedIn(let profile) = viewModel.state else {
            Issue.record("expected .signedIn, got \(viewModel.state)")
            return
        }
        #expect(profile.acceptedTermsVersion == AppConfig.termsVersion)
        #expect(profile.acceptedTermsAt != nil)
    }

    @Test func termsCannotBeAcceptedWithoutAgreeing() async {
        let viewModel = makeViewModel()
        fillSignUp(viewModel)
        await viewModel.submit()

        await viewModel.acceptTerms()

        guard case .needsTerms = viewModel.state else {
            Issue.record("expected .needsTerms, got \(viewModel.state)")
            return
        }
    }

    @Test func acceptFailureStaysInNeedsTermsWithMessage() async {
        let auth = MockAuthService(failures: .init(acceptTerms: .network))
        let viewModel = makeViewModel(auth)
        fillSignUp(viewModel)
        await viewModel.submit()

        viewModel.hasAgreedToTerms = true
        await viewModel.acceptTerms()

        guard case .needsTerms = viewModel.state else {
            Issue.record("expected .needsTerms, got \(viewModel.state)")
            return
        }
        #expect(viewModel.termsError == AuthMessages.network)
        #expect(!viewModel.isAcceptingTerms)
    }

    @Test func decliningTermsSignsOut() async {
        let auth = MockAuthService()
        let viewModel = makeViewModel(auth)
        fillSignUp(viewModel)
        await viewModel.submit()

        await viewModel.declineTerms()

        #expect(viewModel.state == .signedOut)
        #expect(await auth.currentUserID == nil)
    }

    // MARK: - Sign out

    @Test func signOutReturnsToWelcomeAndClearsForm() async {
        let viewModel = makeViewModel(
            MockAuthService(signedInAs: SampleData.profile),
            state: .signedIn(SampleData.profile)
        )
        viewModel.email = "leftover@sfsu.edu"
        viewModel.mode = .signUp

        await viewModel.signOut()

        #expect(viewModel.state == .signedOut)
        #expect(viewModel.email.isEmpty)
        #expect(viewModel.mode == .logIn)
    }

    @Test func signOutFailureKeepsSessionAndReportsError() async {
        let auth = MockAuthService(signedInAs: SampleData.profile, failures: .init(signOut: .unknown))
        let viewModel = makeViewModel(auth, state: .signedIn(SampleData.profile))

        await viewModel.signOut()

        #expect(viewModel.state == .signedIn(SampleData.profile))
        #expect(viewModel.signOutError == AuthMessages.generic)
    }

    // MARK: - Live stream

    @Test func externalSignOutViaStreamReturnsToSignedOut() async {
        let auth = MockAuthService(signedInAs: SampleData.profile)
        let viewModel = AuthViewModel(auth: auth)
        let session = Task { await viewModel.start() }
        defer { session.cancel() }

        #expect(await waitUntil { viewModel.state == .signedIn(SampleData.profile) })
        await auth.simulateExternalSignOut()
        #expect(await waitUntil { viewModel.state == .signedOut })
    }

    @Test func echoedSignUpProfileDoesNotRegressAcceptedTerms() async {
        let auth = MockAuthService()
        let viewModel = AuthViewModel(auth: auth)
        let session = Task { await viewModel.start() }
        defer { session.cancel() }
        #expect(await waitUntil { viewModel.state == .signedOut })

        fillSignUp(viewModel)
        await viewModel.submit()
        viewModel.hasAgreedToTerms = true
        await viewModel.acceptTerms()
        // Let the stream deliver its echoes of the sign-up and accept-terms emissions.
        try? await Task.sleep(for: .milliseconds(200))

        guard case .signedIn(let profile) = viewModel.state else {
            Issue.record("expected .signedIn, got \(viewModel.state)")
            return
        }
        #expect(profile.acceptedTermsVersion == AppConfig.termsVersion)
    }
}
