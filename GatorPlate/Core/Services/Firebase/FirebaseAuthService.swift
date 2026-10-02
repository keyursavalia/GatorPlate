import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

/// Firebase Auth + Firestore `users/{uid}` implementation. Never logs emails or passwords.
nonisolated final class FirebaseAuthService: AuthService {
    private static let usersCollection = "users"
    /// The auth listener can fire before the sign-up profile write lands; retry briefly before failing.
    private static let profileFetchAttempts = 3
    private static let profileFetchRetryDelay: Duration = .milliseconds(400)

    /// Wraps the listener handle so it can be captured by a `@Sendable` termination closure.
    private nonisolated struct ListenerToken: @unchecked Sendable {
        let handle: any NSObjectProtocol
    }

    var currentUserID: String? { Auth.auth().currentUser?.uid }

    func observeCurrentUser() -> AsyncThrowingStream<UserProfile?, any Error> {
        AsyncThrowingStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                guard let uid = user?.uid else {
                    continuation.yield(nil)
                    return
                }
                Task {
                    do {
                        let profile = try await Self.fetchProfile(uid: uid, attempts: Self.profileFetchAttempts)
                        continuation.yield(profile)
                    } catch {
                        Logger.firebase.error("Session profile load failed")
                        continuation.finish(throwing: Self.map(error))
                    }
                }
            }
            let token = ListenerToken(handle: handle)
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(token.handle)
            }
        }
    }

    func signUp(
        email: String,
        password: String,
        displayName: String,
        accountType: AccountType,
        orgName: String?
    ) async throws -> UserProfile {
        let result: AuthDataResult
        do {
            result = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw Self.map(error)
        }

        let profile = UserProfile(
            uid: result.user.uid,
            displayName: displayName,
            email: email,
            accountType: accountType,
            orgName: orgName,
            acceptedTermsVersion: nil,
            acceptedTermsAt: nil,
            notificationsEnabled: false,
            createdAt: Date()
        )

        do {
            let data = try Firestore.Encoder().encode(profile)
            try await Firestore.firestore()
                .collection(Self.usersCollection)
                .document(profile.uid)
                .setData(data)
        } catch {
            // Roll back so the email is not stranded without a profile. Best effort.
            try? await result.user.delete()
            throw Self.map(error)
        }
        return profile
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let result: AuthDataResult
        do {
            result = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw Self.map(error)
        }
        do {
            return try await Self.fetchProfile(uid: result.user.uid, attempts: 1)
        } catch {
            try? Auth.auth().signOut()
            throw Self.map(error)
        }
    }

    func signOut() async throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw Self.map(error)
        }
    }

    func acceptTerms(version: String) async throws -> UserProfile {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        let reference = Firestore.firestore().collection(Self.usersCollection).document(uid)
        do {
            try await reference.updateData([
                "acceptedTermsVersion": version,
                "acceptedTermsAt": Timestamp(date: Date())
            ])
            return try await Self.fetchProfile(uid: uid, attempts: 1)
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: - Helpers

    private static func fetchProfile(uid: String, attempts: Int) async throws -> UserProfile {
        let reference = Firestore.firestore().collection(usersCollection).document(uid)
        var attempt = 0
        while true {
            attempt += 1
            let snapshot = try await reference.getDocument()
            if snapshot.exists {
                return try snapshot.data(as: UserProfile.self)
            }
            guard attempt < attempts else { throw AppError.unknown }
            try await Task.sleep(for: profileFetchRetryDelay)
        }
    }

    /// Maps Firebase errors to `AppError` so raw SDK strings never reach the UI.
    private static func map(_ error: any Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is CancellationError { return .unknown }

        let nsError = error as NSError
        switch nsError.domain {
        case AuthErrorDomain:
            guard let code = AuthErrorCode.Code(rawValue: nsError.code) else { return .unknown }
            switch code {
            case .emailAlreadyInUse: return .emailInUse
            case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail: return .invalidCredentials
            case .weakPassword: return .weakPassword
            case .networkError: return .network
            default: return .unknown
            }
        case FirestoreErrorDomain:
            // gRPC codes: 4 deadline exceeded, 7 permission denied, 14 unavailable.
            switch nsError.code {
            case 4, 14: return .network
            case 7: return .permissionDenied
            default: return .unknown
            }
        case NSURLErrorDomain:
            return .network
        default:
            return .unknown
        }
    }
}
