import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import OSLog

/// Live account management: Firebase Auth for credentials, Firestore `users/{uid}` for the name, and the
/// `deleteAccount` callable (us-central1, App Check enforced) for deletion. Logs never include personal data.
@MainActor
final class FirebaseAccountService: AccountService {
    private var users: CollectionReference { Firestore.firestore().collection("users") }

    func updateProfile(displayName: String, orgName: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        var fields: [String: Any] = ["displayName": displayName]
        if let orgName { fields["orgName"] = orgName }
        let document = users.document(uid)
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.accountWriteTimeoutSeconds) { completion in
                document.updateData(fields) { error in completion(error) }
            }
        } catch is DeadlineExceeded {
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        Logger.services.info("Profile name updated")
    }

    func changePassword(current: String, new: String) async throws {
        let user = try await reauthenticate(password: current)
        do {
            // Completion-handler API: the async overload sends the non-Sendable `User` off the main actor.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                user.updatePassword(to: new) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        Logger.services.info("Password changed")
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            Logger.services.info("Password reset requested")
        } catch {
            let nsError = error as NSError
            // Only a network failure or the rate limit is worth telling the user; anything else (no such account,
            // disabled, ...) looks the same as success, like Firebase's email enumeration protection.
            if nsError.domain == AuthErrorDomain, nsError.code == AuthErrorCode.tooManyRequests.rawValue {
                throw AppError.validation(AccountMessages.resetRateLimited)
            }
            if FirebaseErrorMapper.map(error) == .network { throw AppError.network }
            Logger.services.notice("Password reset request not sent: \(nsError.code, privacy: .public)")
        }
    }

    func sendPasswordResetToCurrentUser() async throws {
        guard let email = Auth.auth().currentUser?.email else { throw AppError.unauthorized }
        try await sendPasswordReset(email: email)
    }

    func deleteAccount(password: String, prepare: () async -> Void) async throws {
        let user = try await reauthenticate(password: password)
        do {
            // The server checks `auth_time`; a fresh token carries the reauthentication.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                user.getIDTokenForcingRefresh(true) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        await prepare()
        let callable = Functions.functions(region: AppConfig.functionsRegion).httpsCallable("deleteAccount")
        callable.timeoutInterval = TimeInterval(AppConfig.accountDeleteTimeoutSeconds)
        do {
            _ = try await callable.call()
        } catch {
            throw Self.mapFunctionsError(error)
        }
        Logger.services.info("Account deleted on the server")
        // The Auth user no longer exists; clear the local session.
        do {
            try Auth.auth().signOut()
        } catch {
            Logger.services.error("Local sign-out after deletion failed")
        }
    }

    // MARK: Helpers

    private func reauthenticate(password: String) async throws -> User {
        guard let user = Auth.auth().currentUser, let email = user.email else { throw AppError.unauthorized }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            _ = try await user.reauthenticate(with: credential)
            return user
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               let code = AuthErrorCode(rawValue: nsError.code),
               code == .wrongPassword || code == .invalidCredential {
                throw AppError.validation(AccountMessages.wrongPassword)
            }
            throw FirebaseErrorMapper.map(error)
        }
    }

    private static func mapFunctionsError(_ error: Error) -> AppError {
        let nsError = error as NSError
        Logger.services.error("deleteAccount failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
        guard nsError.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return FirebaseErrorMapper.map(error)
        }
        switch code {
        case .unavailable, .deadlineExceeded: return .network
        case .failedPrecondition, .unauthenticated:
            return .validation("Please enter your password again and retry.")
        case .permissionDenied: return .permissionDenied
        default: return .unknown
        }
    }
}
