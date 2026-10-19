import FirebaseFirestore
import FirebaseMessaging
import Observation
import OSLog
import UserNotifications

/// Live alerts: UserNotifications for permission and taps, Firebase Messaging registration by Firebase
/// Installation ID (`FirebaseMessagingInstallationIdEnabled`; FCM tokens are deprecated in SDK 12.19),
/// Firestore `users/{uid}` for the opt-in, installation ID and quiet hours. Logs never include IDs or post content.
/// FCM's app-delegate proxy is off (`FirebaseAppDelegateProxyEnabled = NO`): the APNs token and tapped alerts are
/// handled here by hand, so nothing swizzles this delegate.
@MainActor
@Observable
final class FirebaseNotificationService: NSObject, NotificationService {
    private(set) var authorization = NotificationAuthorization.notDetermined
    private(set) var pendingAlert: AlertOpenRequest?

    @ObservationIgnored private let registerForRemoteNotifications: () -> Void
    @ObservationIgnored private let appState: () -> AlertOpenRequest.AppState
    @ObservationIgnored private var activeUid: String?
    @ObservationIgnored private var alertsEnabled = false
    /// Latest ID from `messaging(_:didReceiveRegistration:)`.
    @ObservationIgnored private var installationId: String?
    /// FCM declines to register until it has the APNs device token, so registration waits for it.
    @ObservationIgnored private var hasAPNSToken = false
    @ObservationIgnored private var savedInstallationId: String?

    /// Field names; `functions/src/index.ts` reads the same ones.
    private enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let fcmInstallationId = "fcmInstallationId"
        static let fcmInstallationIdUpdatedAt = "fcmInstallationIdUpdatedAt"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let alertFilters = "alertFilters"
    }

    /// Create during app launch: the delegate must be set before launch finishes so cold-start taps arrive.
    init(registerForRemoteNotifications: @escaping () -> Void,
         appState: @escaping () -> AlertOpenRequest.AppState) {
        self.registerForRemoteNotifications = registerForRemoteNotifications
        self.appState = appState
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Logger.services.info("Notification delegate set")
        Task { await refreshAuthorization() }
    }

    private var users: CollectionReference { Firestore.firestore().collection("users") }

    // MARK: NotificationService

    func alertHandled(_ request: AlertOpenRequest) {
        if pendingAlert == request { pendingAlert = nil }
        clearDelivered(postId: request.postId, notificationId: request.notificationId)
    }

    func refreshAuthorization() async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<NotificationAuthorization, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: NotificationAuthorization(settings.authorizationStatus))
            }
        }
        if status != authorization { authorization = status }
    }

    func requestAuthorization() async -> NotificationAuthorization {
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if error != nil { Logger.services.error("Notification authorization request failed") }
                continuation.resume(returning: granted)
            }
        }
        Logger.services.info("Notification authorization granted: \(granted, privacy: .public)")
        await refreshAuthorization()
        return authorization
    }

    func activate(uid: String, alertsEnabled: Bool) {
        if activeUid != uid { savedInstallationId = nil }
        activeUid = uid
        self.alertsEnabled = alertsEnabled
        guard alertsEnabled else { return }
        Task {
            await refreshAuthorization()
            guard authorization.isAuthorized, activeUid == uid else { return }
            // iOS delivers the APNs token on every launch; `apnsTokenDidArrive` then registers with FCM.
            registerForRemoteNotifications()
            if hasAPNSToken { await registerAndSave(uid: uid) }
        }
    }

    func setAlertsEnabled(_ enabled: Bool, uid: String) async throws {
        activeUid = uid
        if enabled {
            // Set first, so an APNs token arriving while this runs registers and saves the ID.
            alertsEnabled = true
            registerForRemoteNotifications()
            do {
                try await write([Key.notificationsEnabled: true], uid: uid)
            } catch {
                alertsEnabled = false
                throw error
            }
            if hasAPNSToken { await registerAndSave(uid: uid) }
        } else {
            alertsEnabled = false
            try await write([Key.notificationsEnabled: false, Key.fcmInstallationId: FieldValue.delete()], uid: uid)
            savedInstallationId = nil
        }
        Logger.services.info("Alerts enabled: \(enabled, privacy: .public)")
    }

    /// From the app delegate: hands the APNs token to FCM, then registers this device if alerts are on.
    func apnsTokenDidArrive(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        hasAPNSToken = true
        Logger.services.info("APNs token received")
        guard let activeUid, alertsEnabled else { return }
        Task { await registerAndSave(uid: activeUid) }
    }

    func setQuietHours(_ enabled: Bool, uid: String) async throws {
        try await write([Key.quietHoursEnabled: enabled], uid: uid)
    }

    func setAlertFilters(_ filters: AlertFilters, uid: String) async throws {
        // Field names and limits match `firestore.rules` and `functions/src/filters.ts`.
        let fields: [String: Any] = [
            "mode": filters.mode.rawValue,
            "diets": filters.diets.map(\.rawValue),
            "includeUnknownDiet": filters.includeUnknownDiet,
            "places": Array(filters.places.prefix(AppConfig.alertFilterMaxPlaces)),
            "avoidAllergens": filters.avoidAllergens.map(\.rawValue),
            "skipUnverifiedAllergens": filters.skipUnverifiedAllergens,
            "foods": Array(filters.foods.prefix(AppConfig.alertFilterMaxFoods)),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await write([Key.alertFilters: fields], uid: uid)
        Logger.services.info("Alert filters saved")
    }

    func resetForDeletedAccount() {
        activeUid = nil
        alertsEnabled = false
        savedInstallationId = nil
    }

    func deactivate(uid: String) async {
        activeUid = nil
        alertsEnabled = false
        savedInstallationId = nil
        // A tapped alert stays pending: the app continues as a guest and still opens the post.
        do {
            try await write([Key.fcmInstallationId: FieldValue.delete()], uid: uid,
                            deadlineSeconds: AppConfig.notificationSignOutTimeoutSeconds)
        } catch {
            Logger.services.error("Couldn't remove the installation ID before sign-out")
        }
    }

    // MARK: Registration

    /// Registers this app instance with FCM; `messaging(_:didReceiveRegistration:)` then delivers the ID.
    private func registerWithFCM() async {
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.notificationRegisterTimeoutSeconds) { completion in
                Messaging.messaging().register { error in completion(error) }
            }
        } catch {
            // Expected until APNs registration finishes (and always without the Push Notifications capability).
            Logger.services.error("FCM registration failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Registers with FCM (the delegate delivers the ID) and saves the ID for the signed-in user.
    private func registerAndSave(uid: String) async {
        await registerWithFCM()
        guard let installationId, activeUid == uid, alertsEnabled else { return }
        await saveInstallationId(installationId, uid: uid)
    }

    private func saveInstallationId(_ id: String, uid: String) async {
        guard id != savedInstallationId else { return }
        do {
            try await write([Key.fcmInstallationId: id, Key.fcmInstallationIdUpdatedAt: FieldValue.serverTimestamp()],
                            uid: uid)
            savedInstallationId = id
            Logger.services.info("FCM installation ID saved")
        } catch {
            Logger.services.error("FCM installation ID save failed")
        }
    }

    fileprivate func registrationDidChange(_ id: String?) {
        installationId = id
        guard let id, let activeUid, alertsEnabled else { return }
        Task { await saveInstallationId(id, uid: activeUid) }
    }

    // MARK: Tapped alerts

    /// From the delegate (`FirebaseNotificationService+Taps`): keeps the tap until navigation handles it.
    func didOpenNotification(postId: String?, notificationId: String) {
        let state = appState()
        Logger.ui.info("Alert tapped (state: \(state.rawValue, privacy: .public))")
        guard let postId else { return }
        pendingAlert = AlertOpenRequest(postId: postId, appState: state, notificationId: notificationId)
    }

    private func write(_ fields: [String: Any], uid: String,
                       deadlineSeconds: Int = AppConfig.notificationWriteTimeoutSeconds) async throws {
        let document = users.document(uid)
        do {
            try await awaitCompletion(deadlineSeconds: deadlineSeconds) { completion in
                document.updateData(fields) { error in completion(error) }
            }
        } catch is DeadlineExceeded {
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
    }

    /// Post IDs are 20 alphanumeric characters; anything else in a payload is ignored.
    nonisolated static func postId(from userInfo: [AnyHashable: Any]) -> String? {
        guard let postId = userInfo[AppConfig.notificationPostIdKey] as? String,
              (1...40).contains(postId.count),
              postId.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return postId
    }
}

extension FirebaseNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistration installationId: String?) {
        Task { @MainActor in registrationDidChange(installationId) }
    }
}

private nonisolated extension NotificationAuthorization {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral: self = .authorized
        case .denied: self = .denied
        case .notDetermined: self = .notDetermined
        @unknown default: self = .denied
        }
    }
}
