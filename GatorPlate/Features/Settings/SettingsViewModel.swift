import Foundation
import Observation

/// Free food alerts opt-in and quiet hours. The system prompt fires from the first-run chain on the Map
/// (`FirstRunPermissions`) or, if the user skipped it, directly from the Settings toggle.
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var alertsEnabled: Bool
    private(set) var quietHoursEnabled: Bool
    /// Saved "Custom notifications"; nil = all free food.
    private(set) var alertFilters: AlertFilters?
    private(set) var isUpdating = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let notifications: any NotificationService
    @ObservationIgnored private let uid: String

    init(notifications: any NotificationService, profile: UserProfile) {
        self.notifications = notifications
        self.uid = profile.uid
        self.alertsEnabled = profile.notificationsEnabled
        self.quietHoursEnabled = profile.quietHoursEnabled ?? false
        self.alertFilters = profile.alertFilters
    }

    /// True when iOS Settings blocks GatorPlate's notifications.
    var isBlockedBySystem: Bool {
        notifications.authorization == .denied
    }

    static let quietHoursLabel = "Mute notifications 11 PM – 7 AM"

    // MARK: Session

    func activate() {
        notifications.activate(uid: uid, alertsEnabled: alertsEnabled)
        Task { await notifications.refreshAuthorization() }
    }

    func deactivate() async {
        await notifications.deactivate(uid: uid)
    }

    // MARK: Alerts

    /// From the Settings toggle.
    func setAlerts(_ enabled: Bool) async {
        errorMessage = nil
        guard enabled else {
            await apply(false)
            return
        }
        await notifications.refreshAuthorization()
        switch notifications.authorization {
        case .notDetermined:
            // Skipped the first-run chain (e.g. opened from a deep link): ask now.
            if await notifications.requestAuthorization().isAuthorized { await apply(true) }
        case .denied: errorMessage = "Turn on notifications for GatorPlate in iOS Settings first."
        case .authorized: await apply(true)
        }
    }

    /// "Allow" in the first-run chain means opt in (all free food). True when it was saved.
    func optInFromChain() async -> Bool {
        errorMessage = nil
        guard !alertsEnabled else { return true }
        await apply(true)
        return alertsEnabled
    }

    func setQuietHours(_ enabled: Bool) async {
        errorMessage = nil
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await notifications.setQuietHours(enabled, uid: uid)
            quietHoursEnabled = enabled
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Saves the filters (10 s deadline). Throws so the filters screen can show the error inline.
    func saveAlertFilters(_ filters: AlertFilters) async throws {
        do {
            try await notifications.setAlertFilters(filters, uid: uid)
            alertFilters = filters
        } catch {
            throw AppError.validation(Self.message(for: error))
        }
    }

    /// Account deletion: stop alerts locally; the server removes the profile and registration.
    func forgetForDeletedAccount() {
        notifications.resetForDeletedAccount()
    }

    private func apply(_ enabled: Bool) async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await notifications.setAlertsEnabled(enabled, uid: uid)
            alertsEnabled = enabled
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? AppError {
        case .network: "Couldn't save. Check your connection and try again."
        case .permissionDenied: AppError.permissionDenied.userMessage
        default: AppError.unknown.userMessage
        }
    }
}
