import Foundation

@MainActor
final class MockAccountService: AccountService {
    /// The password the mock accepts.
    var password = "password123"
    var error: AppError?
    private(set) var deleted = false

    func updateProfile(displayName: String, orgName: String?) async throws {
        if let error { throw error }
    }

    func changePassword(current: String, new: String) async throws {
        if let error { throw error }
        guard current == password else { throw AppError.validation(AccountMessages.wrongPassword) }
        password = new
    }

    func sendPasswordReset(email: String) async throws {
        if let error { throw error }
    }

    func deleteAccount(password: String, prepare: () async -> Void) async throws {
        if let error { throw error }
        guard password == self.password else { throw AppError.validation(AccountMessages.wrongPassword) }
        await prepare()
        deleted = true
    }
}
