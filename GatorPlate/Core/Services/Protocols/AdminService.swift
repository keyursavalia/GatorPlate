import Foundation

/// Moderation for admins (the `admin` claim, from Remote Config `admin_uids`). Reads reports, appeals and moderation
/// records, and runs actions by writing `adminActions` docs that the `onAdminActionCreated` function processes.
@MainActor
protocol AdminService {
    /// Syncs the `admin` claim with the server and returns whether this account is an admin. False on any error.
    func refreshAdminStatus() async -> Bool
    /// Appeals, newest first (open and decided).
    func observeAppeals() -> AsyncThrowingStream<[AdminAppeal], Error>
    /// Reports from the last 90 days, newest first.
    func observeReports() -> AsyncThrowingStream<[AdminReport], Error>
    func moderation(uid: String) async throws -> AdminModeration?
    /// Writes the action and waits for the function's status (about 20 s at most).
    func run(_ action: AdminActionRequest) async throws -> AdminActionOutcome
}
