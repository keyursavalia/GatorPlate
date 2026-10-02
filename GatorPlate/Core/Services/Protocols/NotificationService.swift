import Foundation

nonisolated protocol NotificationService: Sendable {
    /// True when the backend pushes alerts while the app is closed, so the app must not also schedule local ones.
    var deliversRemotePush: Bool { get }

    func permission() async -> NotificationPermission
    /// Shows the system prompt (once per install). Returns the resulting status.
    func requestPermission() async -> NotificationPermission

    /// Turns alerts on for this user: registers the device and stores the preference.
    func enable(uid: String) async throws
    /// Turns alerts off for this user: removes the device token and stores the preference. Never throws past a
    /// failed write; the local switch is already off.
    func disable(uid: String) async throws
    /// Re-registers a device whose preference is already on (app launch, token refresh). Does not change the preference.
    func activate(uid: String) async
    /// Removes this device's token without changing the preference. Called before sign-out.
    func detachDevice(uid: String) async

    /// Schedules an immediate local notification (app alive in the background).
    func scheduleLocal(_ content: AlertContent) async
}
