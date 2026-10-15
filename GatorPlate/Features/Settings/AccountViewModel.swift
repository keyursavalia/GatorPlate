import Foundation
import Observation

/// Account screen: edit the name (new posts only), change password, delete the account.
@MainActor
@Observable
final class AccountViewModel {
    enum Status: Equatable {
        case idle, working, done(String), failed(String)
    }

    var name: String
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
        self.name = profile.accountType == .organization ? (profile.orgName ?? profile.displayName) : profile.displayName
    }

    var isOrganization: Bool { profile.accountType == .organization }

    /// Same rules as sign-up: not empty, at most `AppConfig.maxNameLength`.
    var nameError: String? {
        let trimmed = Validation.trimmedName(name)
        if trimmed.isEmpty { return isOrganization ? "Enter your organization's name." : "Enter your name." }
        if trimmed.count > AppConfig.maxNameLength { return "Use \(AppConfig.maxNameLength) characters or fewer." }
        return nil
    }

    var canSaveName: Bool {
        nameError == nil && Validation.trimmedName(name) != currentName && nameStatus != .working
    }

    private var currentName: String {
        isOrganization ? (profile.orgName ?? profile.displayName) : profile.displayName
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
            nameStatus = .done("Saved. Changes apply to new posts.")
        } catch {
            nameStatus = .failed(Self.message(for: error))
        }
    }

    func changePassword(current: String, new: String, confirm: String) async -> Bool {
        guard Validation.isPasswordValid(new) else {
            passwordStatus = .failed("Use at least \(AppConfig.minPasswordLength) characters.")
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
