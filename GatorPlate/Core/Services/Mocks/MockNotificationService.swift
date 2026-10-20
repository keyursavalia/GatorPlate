import Foundation
import Observation

@MainActor
@Observable
final class MockNotificationService: NotificationService {
    var authorization: NotificationAuthorization
    var pendingAlert: AlertOpenRequest?
    var hasPendingAppealResult = false
    private(set) var handledAlerts: [AlertOpenRequest] = []
    /// What `requestAuthorization` grants.
    var grants = true
    var setError: AppError?
    private(set) var alertsEnabled = false
    private(set) var quietHours = false
    private(set) var alertFilters: AlertFilters?
    private(set) var activeUid: String?

    init(authorization: NotificationAuthorization = .notDetermined) {
        self.authorization = authorization
    }

    func alertHandled(_ request: AlertOpenRequest) {
        handledAlerts.append(request)
        if pendingAlert == request { pendingAlert = nil }
    }

    func appealResultHandled() {
        hasPendingAppealResult = false
    }

    func refreshAuthorization() async {}

    func requestAuthorization() async -> NotificationAuthorization {
        if authorization == .notDetermined { authorization = grants ? .authorized : .denied }
        return authorization
    }

    func activate(uid: String, alertsEnabled: Bool) {
        activeUid = uid
        self.alertsEnabled = alertsEnabled
    }

    func setAlertsEnabled(_ enabled: Bool, uid: String) async throws {
        if let setError { throw setError }
        alertsEnabled = enabled
    }

    func setQuietHours(_ enabled: Bool, uid: String) async throws {
        if let setError { throw setError }
        quietHours = enabled
    }

    func deactivate(uid: String) async {
        activeUid = nil
        alertsEnabled = false
    }

    func setAlertFilters(_ filters: AlertFilters, uid: String) async throws {
        if let setError { throw setError }
        alertFilters = filters
    }

    func resetForDeletedAccount() {
        activeUid = nil
        alertsEnabled = false
    }
}
