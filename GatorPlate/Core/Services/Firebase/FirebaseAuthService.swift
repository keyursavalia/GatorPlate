import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

/// Live auth: Firebase Auth for credentials (anonymous for guests), Firestore `users/{uid}` for the profile.
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

    func signInAsGuest(acceptedTermsVersion: String, acceptedTermsAt: Date) async throws {
        isSigningUp = true
        defer { isSigningUp = false }
        do {
            let result = try await Auth.auth().signInAnonymously()
            do {
                try await createGuestProfile(uid: result.user.uid, termsVersion: acceptedTermsVersion,
                                             termsAcceptedAt: acceptedTermsAt)
            } catch {
                // Roll back so the next attempt starts clean.
                try? await result.user.delete()
                throw error
            }
            Logger.services.info("Guest session started")
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        isSigningUp = false
        await emit(to: Array(continuations.values))
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        isSigningUp = true
        defer { isSigningUp = false }
        do {
            if let guest = Auth.auth().currentUser, guest.isAnonymous {
                try await upgradeGuest(guest, email: email, password: password, displayName: displayName)
            } else {
                try await createAccount(email: email, password: password, displayName: displayName)
            }
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        if AppConfig.requireEmailVerification, let user = Auth.auth().currentUser {
            do { try await user.sendEmailVerification() } catch {
                Logger.services.error("Initial verification email failed; user can resend")
            }
        }
        isSigningUp = false
        await emit(to: Array(continuations.values))
    }

    func signIn(email: String, password: String) async throws {
        let guest = Auth.auth().currentUser.flatMap { $0.isAnonymous ? $0 : nil }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        // The guest's profile stays behind without an alert registration (removed before sign-in).
        guest?.delete { error in
            if error != nil { Logger.services.notice("Old guest user not deleted") }
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
            let wasVerified = user.isEmailVerified
            do {
                try await user.reload()
            } catch {
                throw FirebaseErrorMapper.map(error)
            }
            // `reload` updates the user, not the ID token: rules that read `email_verified` (reports) would keep
            // seeing false for up to an hour. Mint a new token as soon as verification lands.
            if !wasVerified, user.isEmailVerified {
                await Self.refreshIDToken(user)
            }
        }
        await emit(to: Array(continuations.values))
    }

    /// Best effort; the token refreshes on its own within the hour if this fails.
    private static func refreshIDToken(_ user: User) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            user.getIDTokenForcingRefresh(true) { _, error in
                if error != nil { Logger.services.error("ID token refresh after verification failed") }
                continuation.resume()
            }
        }
        Logger.services.info("ID token refreshed after email verification")
    }

    // MARK: Accounts

    private func createAccount(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let profile = UserProfile(uid: result.user.uid, displayName: displayName, email: email,
                                  accountType: .student, orgName: nil,
                                  acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                  notificationsEnabled: false, createdAt: .now)
        do {
            try await writeProfile(profile)
        } catch {
            // Roll back so the user can retry with the same email.
            try? await result.user.delete()
            throw error
        }
    }

    /// Links the email credential to the anonymous user (same uid), then turns the guest profile into an account.
    /// Alert settings and the accepted Terms stay. If the profile can't be updated, the link is undone.
    private func upgradeGuest(_ guest: User, email: String, password: String, displayName: String) async throws {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        // Completion-handler APIs: the async overloads send the non-Sendable `User` off the main actor.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guest.link(with: credential) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        do {
            // The rules compare the profile email with the token's, so the token must carry the new email.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guest.getIDTokenForcingRefresh(true) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            let fields: [String: Any] = [
                "displayName": displayName,
                "email": email,
                "accountType": AccountType.student.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
            ]
            let document = users.document(guest.uid)
            try await confirmed { completion in document.updateData(fields) { completion($0) } }
            Logger.services.info("Guest upgraded to an account")
        } catch {
            guest.unlink(fromProvider: EmailAuthProviderID) { _, unlinkError in
                if unlinkError != nil { Logger.services.error("Couldn't undo the account link") }
            }
            throw error
        }
    }

    private func createGuestProfile(uid: String, termsVersion: String?, termsAcceptedAt: Date?) async throws {
        let profile = UserProfile(uid: uid, displayName: AccountType.guest.displayName, email: nil,
                                  accountType: .guest, orgName: nil, acceptedTermsVersion: termsVersion,
                                  acceptedTermsAt: termsAcceptedAt, notificationsEnabled: false, createdAt: .now)
        try await writeProfile(profile)
    }

    /// Waits for the server, so a rules rejection surfaces here (and can be rolled back) instead of later.
    private func writeProfile(_ profile: UserProfile) async throws {
        let document = users.document(profile.uid)
        let fields = try Firestore.Encoder().encode(profile)
        try await confirmed { completion in document.setData(fields) { completion($0) } }
    }

    private func confirmed(_ start: (@escaping @Sendable (Error?) -> Void) -> Void) async throws {
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.accountWriteTimeoutSeconds, start)
        } catch is DeadlineExceeded {
            throw AppError.network
        }
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
            let document = users.document(user.uid)
            var snapshot = try await document.getDocument()
            if !snapshot.exists, user.isAnonymous {
                // A guest whose profile was never written (e.g. the app quit mid-setup).
                let terms = TermsAcceptance()
                try await createGuestProfile(uid: user.uid, termsVersion: terms.isCurrent ? AppConfig.termsVersion : nil,
                                             termsAcceptedAt: terms.acceptedAt)
                snapshot = try await document.getDocument()
            }
            let profile = try snapshot.data(as: UserProfile.self)
            return .success(AuthSession(profile: profile, isEmailVerified: user.isEmailVerified))
        } catch {
            let nsError = error as NSError
            Logger.services.error("Profile load failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            return .failure(FirebaseErrorMapper.map(error))
        }
    }
}
