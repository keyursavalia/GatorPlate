import Foundation

/// Opt-in free food alerts. Implementations are `@Observable` so Settings and the tab view react to changes.
/// The device's FCM installation ID is stored at `users/{uid}.fcmInstallationId` only while alerts are on; the
/// `onPostCreated` Cloud Function sends one alert per ID and skips the author. Alerts are broadcast, never targeted by need.
@MainActor
protocol NotificationService: AnyObject {
    var authorization: NotificationAuthorization { get }
    /// Post ID from a tapped alert, waiting to be opened.
    var pendingOpenPostId: String? { get }

    /// Returns and clears `pendingOpenPostId`.
    func consumePendingOpen() -> String?
    func refreshAuthorization() async
    /// Shows the system prompt (iOS shows it once). Call only after explaining the value.
    func requestAuthorization() async -> NotificationAuthorization
    /// After sign-in: re-registers this device and refreshes its installation ID if the user has alerts on.
    func activate(uid: String, alertsEnabled: Bool)
    /// Opt in or out for this user. Opting out removes the installation ID.
    func setAlertsEnabled(_ enabled: Bool, uid: String) async throws
    func setQuietHours(_ enabled: Bool, uid: String) async throws
    /// Before sign-out: removes this device's installation ID so a signed-out phone gets no alerts. Never throws.
    func deactivate(uid: String) async
}
