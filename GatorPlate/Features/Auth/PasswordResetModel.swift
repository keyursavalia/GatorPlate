import Foundation
import Observation
import OSLog

/// "Forgot password": sends Firebase's hosted reset link and shows a "Check your email" state. The result never
/// says whether an account exists. Owned by `AuthViewModel` (one per launch), so the resend cooldown survives
/// closing and reopening the sheet and the button can't be used to spam.
@MainActor
@Observable
final class PasswordResetModel {
    enum Phase: Equatable {
        case form
        /// The generic "If an account exists for <email>" state.
        case sent(email: String)
    }

    private(set) var phase = Phase.form
    private(set) var isSending = false
    /// Validation, network or rate-limit message for the form. Nothing else is ever shown (decision: never reveal).
    private(set) var errorMessage: String?
    /// Send and Resend stay disabled until then.
    private(set) var resendAvailableAt: Date?

    @ObservationIgnored private let account: any AccountService
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let cooldown: TimeInterval
    /// The last send went to the signed-in account (no typed email).
    @ObservationIgnored private var sentToCurrentUser = false

    init(account: any AccountService, now: @escaping () -> Date = { .now },
         cooldownSeconds: Int = AppConfig.passwordResetResendSeconds) {
        self.account = account
        self.now = now
        self.cooldown = TimeInterval(cooldownSeconds)
    }

    /// Whole seconds until Resend works again; 0 when it's available.
    func secondsUntilResend(at date: Date) -> Int {
        guard let resendAvailableAt else { return 0 }
        return max(0, Int(resendAvailableAt.timeIntervalSince(date).rounded(.up)))
    }

    func isCoolingDown(at date: Date) -> Bool {
        secondsUntilResend(at: date) > 0
    }

    /// The sheet opens: back to the form unless a link went out moments ago (then "Check your email" again).
    func prepareForOpen() {
        errorMessage = nil
        if !isCoolingDown(at: now()) { phase = .form }
    }

    /// "Use a different email" from the Sent state.
    func editEmail() {
        errorMessage = nil
        phase = .form
    }

    /// From the form. Same email rules as Sign in.
    func send(email raw: String) async {
        let email = Validation.normalizedEmail(raw)
        if let message = Validation.emailMessage(raw) {
            errorMessage = message
            return
        }
        sentToCurrentUser = false
        await deliver(to: email) { [account] in try await account.sendPasswordReset(email: email) }
    }

    /// Account > Change password > "Forgot your current password?". `email` is only for the Sent message.
    func sendToCurrentUser(email: String) async {
        sentToCurrentUser = true
        await deliver(to: email) { [account] in try await account.sendPasswordResetToCurrentUser() }
    }

    func resend() async {
        guard case .sent(let email) = phase else { return }
        if sentToCurrentUser {
            await sendToCurrentUser(email: email)
        } else {
            await send(email: email)
        }
    }

    private func deliver(to email: String, _ request: () async throws -> Void) async {
        guard !isSending, !isCoolingDown(at: now()) else { return }
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            try await request()
        } catch let error as AppError {
            switch error {
            case .network, .validation:
                // The form stays (or the Sent state keeps its email) with the message.
                errorMessage = error.userMessage
                return
            case .unauthorized:
                // No signed-in email to send to (never reached from the typed-email form).
                errorMessage = AppError.unknown.userMessage
                return
            default:
                // Anything else looks the same as success.
                Logger.ui.error("Password reset request failed")
            }
        } catch {
            Logger.ui.error("Password reset request failed")
        }
        resendAvailableAt = now().addingTimeInterval(cooldown)
        phase = .sent(email: email)
    }
}
