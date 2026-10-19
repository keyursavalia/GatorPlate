import Foundation
import Observation

/// Account screen: edit the name (new posts only), change password, delete the account.
@MainActor
@Observable
final class AccountViewModel {
    enum Status: Equatable {
        case idle, working, done(String), failed(String)
    }

    /// How long the "Saved" check stays before the pencil returns.
    static let savedConfirmationSeconds = 2.0

    var name: String {
        didSet {
            // Editing again clears the last "Saved" / error line.
            if nameStatus != .working, name != oldValue { nameStatus = .idle }
        }
    }
    /// The name as last saved (the profile passed in is a snapshot and doesn't update).
    private(set) var savedName: String
    private(set) var nameStatus = Status.idle
    private(set) var passwordStatus = Status.idle
    private(set) var deleteStatus = Status.idle

    let profile: UserProfile
    @ObservationIgnored private let account: any AccountService
    @ObservationIgnored private let auth: any AuthService
    @ObservationIgnored private let onDelete: (String) async throws -> Void

    init(profile: UserProfile, account: any AccountService, auth: any AuthService,
         onDelete: @escaping (String) async throws -> Void) {
        self.profile = profile
        self.account = account
        self.auth = auth
        self.onDelete = onDelete
        let current = profile.accountType == .organization ? (profile.orgName ?? profile.displayName) : profile.displayName
        self.name = current
        self.savedName = current
    }

    var isOrganization: Bool { profile.accountType == .organization }

    /// Same rules as sign-up: not empty, at most `AppConfig.maxNameLength`.
    var nameError: String? {
        let trimmed = Validation.trimmedName(name)
        if trimmed.isEmpty { return isOrganization ? "Enter your organization's name." : "Enter your name." }
        if trimmed.count > AppConfig.maxNameLength { return "Use \(AppConfig.maxNameLength) characters or fewer." }
        return nil
    }

    /// The name differs from the saved one (the Save button shows only then).
    var hasNameChanges: Bool {
        Validation.trimmedName(name) != savedName
    }

    var canSaveName: Bool {
        nameError == nil && hasNameChanges && nameStatus != .working
    }

    var memberSince: String {
        profile.createdAt.formatted(.dateTime.month(.wide).year())
    }

    // MARK: Actions

    func saveName() async {
        guard canSaveName else { return }
        nameStatus = .working
        let trimmed = Validation.trimmedName(name)
        do {
            // Organizations post under their org name, so both fields stay equal (as at sign-up).
            try await account.updateProfile(displayName: trimmed, orgName: isOrganization ? trimmed : nil)
            try? await auth.refreshSession()
            savedName = trimmed
            name = trimmed
            nameStatus = .done("Saved")
        } catch {
            nameStatus = .failed(Self.message(for: error))
        }
    }

    func clearSavedStatus() {
        if case .done = nameStatus { nameStatus = .idle }
    }

    func changePassword(current: String, new: String, confirm: String) async -> Bool {
        guard Validation.isPasswordValid(new) else {
            passwordStatus = .failed(Validation.weakPasswordMessage)
            return false
        }
        guard new == confirm else {
            passwordStatus = .failed("The new passwords don't match.")
            return false
        }
        passwordStatus = .working
        do {
            try await account.changePassword(current: current, new: new)
            passwordStatus = .done("Password changed.")
            return true
        } catch {
            passwordStatus = .failed(Self.message(for: error))
            return false
        }
    }

    func deleteAccount(password: String) async {
        guard !password.isEmpty, deleteStatus != .working else { return }
        deleteStatus = .working
        do {
            try await onDelete(password)
            deleteStatus = .idle
        } catch {
            deleteStatus = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? AppError {
        case .network: "Couldn't reach the server. Check your connection and try again."
        case .unauthorized: AccountMessages.wrongPassword
        case .validation(let message): message
        default: AppError.unknown.userMessage
        }
    }
}
