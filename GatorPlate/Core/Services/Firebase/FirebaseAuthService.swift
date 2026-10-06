import Foundation
import OSLog

/// Live auth. Stub until Sprint 01.
@MainActor
final class FirebaseAuthService: AuthService {
    var currentUserId: String? { nil }

    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws -> UserProfile {
        Logger.services.notice("FirebaseAuthService.signUp not implemented")
        throw AppError.unknown
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        Logger.services.notice("FirebaseAuthService.signIn not implemented")
        throw AppError.unknown
    }

    func signOut() throws {
        throw AppError.unknown
    }
}
