import Foundation
import Observation

/// Whether this account is an admin (the `admin` claim, synced from Remote Config `admin_uids` once per session).
/// Settings shows Moderation only when it is; guests are never admins.
@MainActor
@Observable
final class AdminAccess {
    private(set) var isAdmin = false

    @ObservationIgnored private let service: any AdminService
    @ObservationIgnored private let isAccount: Bool
    @ObservationIgnored private var task: Task<Void, Never>?

    init(service: any AdminService, isAccount: Bool) {
        self.service = service
        self.isAccount = isAccount
    }

    /// Once per session; safe to call again.
    func refresh() {
        guard isAccount, task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            isAdmin = await service.refreshAdminStatus()
        }
    }
}
