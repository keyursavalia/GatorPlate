import Foundation
import Observation

/// Free food alerts opt-in and quiet hours. The system prompt is shown only after an in-app explanation
/// (the Settings explainer or the Feed offer), because iOS asks only once.
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var alertsEnabled: Bool
    private(set) var quietHoursEnabled: Bool
    private(set) var isUpdating = false
    private(set) var errorMessage: String?
    var isShowingExplainer = false

    @ObservationIgnored private let notifications: any NotificationService
    @ObservationIgnored private let uid: String

    init(notifications: any NotificationService, profile: UserProfile) {
        self.notifications = notifications
        self.uid = profile.uid
        self.alertsEnabled = profile.notificationsEnabled
        self.quietHoursEnabled = profile.quietHoursEnabled ?? false
    }

    /// True when iOS Settings blocks GatorPlate's notifications.
    var isBlockedBySystem: Bool {
        notifications.authorization == .denied
    }

    /// The Feed offers alerts until the user decides, once.
    var shouldOfferAlerts: Bool {
        !alertsEnabled && notifications.authorization == .notDetermined
    }

    static let quietHoursLabel = "Mute alerts 11 PM – 7 AM"

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
        case .notDetermined: isShowingExplainer = true
        case .denied: errorMessage = "Turn on notifications for GatorPlate in iOS Settings first."
        case .authorized: await apply(true)
        }
    }

    /// After the explanation: shows the system prompt, then opts in if allowed.
    func confirmAlerts() async {
        errorMessage = nil
        guard await notifications.requestAuthorization().isAuthorized else { return }
        await apply(true)
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
