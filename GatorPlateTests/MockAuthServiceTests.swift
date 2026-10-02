import Foundation
import Testing
@testable import GatorPlate

struct MockAuthServiceTests {
    private func signUp(_ service: MockAuthService, email: String = "ada@sfsu.edu") async throws -> UserProfile {
        try await service.signUp(
            email: email,
            password: "password1",
            displayName: "Ada",
            accountType: .student,
            orgName: nil
        )
    }

    @Test func startsSignedOutAndSignUpCreatesProfileWithoutTerms() async throws {
        let service = MockAuthService()
        #expect(await service.currentUserID == nil)

        let profile = try await signUp(service)
        #expect(profile.acceptedTermsVersion == nil)
        #expect(profile.acceptedTermsAt == nil)
        #expect(await service.currentUserID == profile.uid)
    }

    @Test func duplicateEmailThrowsEmailInUse() async throws {
        let service = MockAuthService()
        _ = try await signUp(service)
        await #expect(throws: AppError.emailInUse) { try await signUp(service) }
    }

    @Test func signInChecksPassword() async throws {
        let service = MockAuthService()
        _ = try await signUp(service)
        try await service.signOut()

        await #expect(throws: AppError.invalidCredentials) {
            try await service.signIn(email: "ada@sfsu.edu", password: "wrong-password")
        }
        let profile = try await service.signIn(email: "ada@sfsu.edu", password: "password1")
        #expect(profile.displayName == "Ada")
    }

    @Test func acceptTermsStoresVersionAndInjectedTime() async throws {
        let fixed = Date(timeIntervalSince1970: 1_800_000_000)
        let service = MockAuthService(now: { fixed })
        _ = try await signUp(service)

        let profile = try await service.acceptTerms(version: "v9")
        #expect(profile.acceptedTermsVersion == "v9")
        #expect(profile.acceptedTermsAt == fixed)
    }

    @Test func acceptTermsWhenSignedOutIsUnauthorized() async {
        let service = MockAuthService()
        await #expect(throws: AppError.unauthorized) { try await service.acceptTerms(version: "v1") }
    }

    @Test func injectedFailuresAreThrown() async {
        let service = MockAuthService(failures: .init(signUp: .network))
        await #expect(throws: AppError.network) { try await signUp(service) }
    }

    @Test func streamYieldsCurrentStateThenFinishesWhenNotKeptOpen() async throws {
        let service = MockAuthService(signedInAs: SampleData.profile, keepsStreamOpen: false)
        var emitted: [UserProfile?] = []
        for try await profile in service.observeCurrentUser() { emitted.append(profile) }
        #expect(emitted == [SampleData.profile])
    }

    @Test func streamFailureIsThrown() async {
        let service = MockAuthService(failures: .init(session: .network))
        await #expect(throws: AppError.network) {
            for try await _ in service.observeCurrentUser() {}
        }
    }

    @Test func profileTermsCheckComparesVersions() {
        var profile = SampleData.profile
        #expect(!profile.needsTermsAcceptance(currentVersion: AppConfig.termsVersion))
        profile.acceptedTermsVersion = "old"
        #expect(profile.needsTermsAcceptance(currentVersion: AppConfig.termsVersion))
        profile.acceptedTermsVersion = nil
        #expect(profile.needsTermsAcceptance(currentVersion: AppConfig.termsVersion))
    }
}
