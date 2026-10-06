import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

/// Live auth: Firebase Auth for credentials, Firestore `users/{uid}` for the profile.
@MainActor
final class FirebaseAuthService: AuthService {
    private typealias Event = Result<AuthSession?, AppError>

    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]
    private var listenerHandle: AuthStateDidChangeListenerHandle?
    /// Holds back listener emissions until the profile document exists.
    private var isSigningUp = false

    private var users: CollectionReference { Firestore.firestore().collection("users") }

    // MARK: AuthService

    var currentUser: AsyncStream<Result<AuthSession?, AppError>> {
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        startListeningIfNeeded()
        Task { await emit(to: [continuation]) }
        return stream
    }

    func signUp(email: String, password: String, displayName: String,
                accountType: AccountType, orgName: String?) async throws {
        isSigningUp = true
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let profile = UserProfile(uid: result.user.uid, displayName: displayName, email: email,
                                      accountType: accountType, orgName: orgName,
                                      acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                      notificationsEnabled: false, createdAt: .now)
            do {
                try await users.document(profile.uid).setData(from: profile)
            } catch {
                // Roll back so the user can retry with the same email.
                try? await result.user.delete()
                throw error
            }
            if AppConfig.requireEmailVerification {
                do { try await result.user.sendEmailVerification() } catch {
                    Logger.services.error("Initial verification email failed; user can resend")
                }
            }
        } catch {
            isSigningUp = false
            throw FirebaseErrorMapper.map(error)
        }
        isSigningUp = false
        await emit(to: Array(continuations.values))
    }

    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    func acceptTerms(version: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        do {
            try await users.document(uid).updateData([
                "acceptedTermsVersion": version,
                "acceptedTermsAt": Timestamp(date: .now),
            ])
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        await emit(to: Array(continuations.values))
    }

    func sendVerificationEmail() async throws {
        guard let user = Auth.auth().currentUser else { throw AppError.unauthorized }
        do {
            try await user.sendEmailVerification()
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    func refreshSession() async throws {
        if let user = Auth.auth().currentUser {
            do {
                try await user.reload()
            } catch {
                throw FirebaseErrorMapper.map(error)
            }
        }
        await emit(to: Array(continuations.values))
    }

    // MARK: Session loading

    private func startListeningIfNeeded() {
        guard listenerHandle == nil else { return }
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                guard let self, !self.isSigningUp else { return }
                await self.emit(to: Array(self.continuations.values))
            }
        }
    }

    private func emit(to targets: [AsyncStream<Event>.Continuation]) async {
        guard !isSigningUp else { return }
        let event = await loadSession()
        for continuation in targets { continuation.yield(event) }
    }

    private func loadSession() async -> Event {
        guard let user = Auth.auth().currentUser else { return .success(nil) }
        do {
            let profile = try await users.document(user.uid).getDocument(as: UserProfile.self)
            return .success(AuthSession(profile: profile, isEmailVerified: user.isEmailVerified))
        } catch {
            let nsError = error as NSError
            Logger.services.error("Profile load failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            return .failure(FirebaseErrorMapper.map(error))
        }
    }
}
