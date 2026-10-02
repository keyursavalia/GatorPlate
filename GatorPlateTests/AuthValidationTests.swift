import Testing
@testable import GatorPlate

struct AuthValidationTests {
    @Test(arguments: [
        "student@sfsu.edu",
        "student@mail.sfsu.edu",
        "Student@MAIL.SFSU.EDU",
        "  student@mail.sfsu.edu  ",
        "first.last+club@sfsu.edu"
    ])
    func acceptsSFSUEmails(email: String) {
        #expect(AuthValidation.isValidSFSUEmail(email))
    }

    @Test(arguments: [
        "test@gmail.com",
        "x@sfsu.edu.evil.com",
        "x@evilsfsu.edu",
        "x@notmail.sfsu.edu",
        "x@sub.mail.sfsu.edu",
        "x@@sfsu.edu",
        "x@sfsu.edu@evil.com",
        "@sfsu.edu",
        "sfsu.edu",
        "x y@sfsu.edu",
        "",
        "   "
    ])
    func rejectsNonSFSUEmails(email: String) {
        #expect(!AuthValidation.isValidSFSUEmail(email))
    }

    @Test func normalizesEmailByTrimmingAndLowercasing() {
        #expect(AuthValidation.normalizedEmail("  Ada@Mail.SFSU.edu\n") == "ada@mail.sfsu.edu")
    }

    @Test func passwordNeedsEightCharacters() {
        #expect(!AuthValidation.isValidPassword("1234567"))
        #expect(AuthValidation.isValidPassword("12345678"))
        #expect(AuthValidation.isValidPassword("        "), "spaces count; the password is not trimmed")
    }

    // MARK: - Form input

    private func validInput(_ type: AccountType = .student) -> AuthFormInput {
        AuthFormInput(
            email: "ada@mail.sfsu.edu",
            password: "password1",
            name: "Ada",
            orgName: "Gator Club",
            accountType: type
        )
    }

    @Test func validStudentSignUpHasNoErrors() {
        #expect(validInput().validate(mode: .signUp).isEmpty)
    }

    @Test func validOrganizationSignUpHasNoErrors() {
        #expect(validInput(.organization).validate(mode: .signUp).isEmpty)
    }

    @Test func organizationRequiresOrgName() {
        var input = validInput(.organization)
        input.orgName = ""
        #expect(input.validate(mode: .signUp)[.orgName] == AuthMessages.missingOrgName)
        input.orgName = "   "
        #expect(input.validate(mode: .signUp)[.orgName] == AuthMessages.missingOrgName)
    }

    @Test func studentIgnoresOrgName() {
        var input = validInput(.student)
        input.orgName = ""
        #expect(input.validate(mode: .signUp).isEmpty)
        #expect(input.resolvedOrgName == nil)
    }

    @Test func studentRequiresName() {
        var input = validInput(.student)
        input.name = "  "
        #expect(input.validate(mode: .signUp)[.name] == AuthMessages.missingName)
    }

    @Test func nameLengthsAreCapped() {
        var student = validInput(.student)
        student.name = String(repeating: "a", count: AppConfig.maxDisplayNameLength + 1)
        #expect(student.validate(mode: .signUp)[.name] != nil)

        var org = validInput(.organization)
        org.orgName = String(repeating: "a", count: AppConfig.maxOrgNameLength + 1)
        #expect(org.validate(mode: .signUp)[.orgName] != nil)
    }

    @Test func displayNameIsTypedNameForStudentAndOrgNameForOrganization() {
        var input = validInput(.student)
        input.name = "  Ada  "
        #expect(input.displayName == "Ada")

        input.accountType = .organization
        input.orgName = " Gator Club "
        #expect(input.displayName == "Gator Club")
        #expect(input.resolvedOrgName == "Gator Club")
    }

    @Test func signUpUsesWeakPasswordMessage() {
        var input = validInput()
        input.password = "short"
        #expect(input.validate(mode: .signUp)[.password] == AuthMessages.weakPassword)
    }

    @Test func logInOnlyRequiresAPassword() {
        var input = AuthFormInput(email: "ada@sfsu.edu", password: "short")
        #expect(input.validate(mode: .logIn).isEmpty)
        input.password = ""
        #expect(input.validate(mode: .logIn)[.password] == AuthMessages.missingPassword)
    }

    @Test func logInStillChecksEmailDomain() {
        let input = AuthFormInput(email: "test@gmail.com", password: "password1")
        #expect(input.validate(mode: .logIn)[.email] == AuthMessages.invalidEmail)
    }

    @Test func errorCopyMatchesSprintTable() {
        #expect(AuthMessages.invalidEmail == "Use your SFSU email (ends in @sfsu.edu or @mail.sfsu.edu).")
        #expect(AuthMessages.message(for: .weakPassword) == "Use at least 8 characters.")
        #expect(AuthMessages.message(for: .emailInUse) == "That email already has an account. Try logging in.")
        #expect(AuthMessages.message(for: .invalidCredentials) == "Email or password is incorrect.")
        #expect(AuthMessages.message(for: .network) == "No connection. Check your internet and try again.")
        #expect(AuthMessages.message(for: .unknown) == AuthMessages.generic)
    }
}
