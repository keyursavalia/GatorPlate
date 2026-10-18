import Foundation

/// Opt-in free food alerts. Implementations are `@Observable` so Settings and the tab view react to changes.
/// The device's FCM installation ID is stored at `users/{uid}.fcmInstallationId` only while alerts are on; the
/// `onPostCreated` Cloud Function sends one alert per ID and skips the author. Alerts are broadcast, never targeted by need.
@MainActor
protocol NotificationService: AnyObject {
    var authorization: NotificationAuthorization { get }
    /// A tapped alert whose post hasn't been opened yet. Kept until `alertHandled(_:)`.
    var pendingAlert: AlertOpenRequest? { get }

    /// Navigation opened the post or showed "no longer available": forget the request and clear its alert
    /// from Notification Center.
    func alertHandled(_ request: AlertOpenRequest)
    func refreshAuthorization() async
    /// Shows the system prompt (iOS shows it once). Call only after explaining the value.
    func requestAuthorization() async -> NotificationAuthorization
    /// After sign-in: re-registers this device and refreshes its installation ID if the user has alerts on.
    func activate(uid: String, alertsEnabled: Bool)
    /// Opt in or out for this user. Opting out removes the installation ID.
    func setAlertsEnabled(_ enabled: Bool, uid: String) async throws
    func setQuietHours(_ enabled: Bool, uid: String) async throws
    /// "What to alert me about" at `users/{uid}.alertFilters` (the function applies them).
    func setAlertFilters(_ filters: AlertFilters, uid: String) async throws
    /// Account deletion: forget this user locally. No Firestore write (the server deletes the profile).
    func resetForDeletedAccount()
    /// Before sign-out: removes this device's installation ID so a signed-out phone gets no alerts. Never throws.
    func deactivate(uid: String) async

    #if DEBUG
    /// A local alert with the same payload as the real push, `AppConfig.debugTestAlertDelaySeconds` from now, so
    /// taps can be tested from a killed, background or foreground app without a second account.
    func scheduleTestAlert(postId: String) async throws
    #endif
}
