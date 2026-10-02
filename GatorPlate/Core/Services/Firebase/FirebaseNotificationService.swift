import FirebaseFirestore
import FirebaseMessaging
import Foundation
import OSLog
import os
import UIKit

/// Tier B: FCM token handling. The token and the opt-in flag live on `users/{uid}`; the `onPostCreated` Cloud
/// Function sends to every opted-in user except the author. Tokens are never logged.
nonisolated final class FirebaseNotificationService: NSObject, NotificationService, MessagingDelegate, @unchecked Sendable {
    private static let usersCollection = "users"
    private static let writeTimeout: Duration = .seconds(10)

    private let notifier = LocalNotifier()
    /// Uid whose token a refresh should be stored for. Nil when alerts are off or nobody is signed in.
    private let activeUID = OSAllocatedUnfairLock<String?>(initialState: nil)

    var deliversRemotePush: Bool { true }

    func permission() async -> NotificationPermission { await notifier.permission() }
    func requestPermission() async -> NotificationPermission { await notifier.requestPermission() }
    func scheduleLocal(_ content: AlertContent) async { await notifier.schedule(content) }

    func enable(uid: String) async throws {
        try await FirestoreWrite.update(
            reference(uid),
            fields: ["notificationsEnabled": true],
            timeout: Self.writeTimeout
        )
        await activate(uid: uid)
    }

    func disable(uid: String) async throws {
        activeUID.withLock { $0 = nil }
        await unregister()
        try await FirestoreWrite.update(
            reference(uid),
            fields: ["notificationsEnabled": false, "fcmToken": FieldValue.delete()],
            timeout: Self.writeTimeout
        )
    }

    func activate(uid: String) async {
        activeUID.withLock { $0 = uid }
        await MainActor.run {
            Messaging.messaging().delegate = self
            UIApplication.shared.registerForRemoteNotifications()
        }
        // The delegate callback below also fires once the APNs token is known; this covers a token that already exists.
        if let token = try? await Messaging.messaging().token() {
            await store(token: token, uid: uid)
        }
    }

    func detachDevice(uid: String) async {
        activeUID.withLock { $0 = nil }
        await unregister()
        do {
            try await FirestoreWrite.update(
                reference(uid),
                fields: ["fcmToken": FieldValue.delete()],
                timeout: Self.writeTimeout
            )
        } catch {
            Logger.firebase.error("Removing the device token failed")
        }
    }

    // MARK: MessagingDelegate

    /// Token refresh. Stored only while alerts are on for the signed-in user.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, let uid = activeUID.withLock({ $0 }) else { return }
        Task { await store(token: fcmToken, uid: uid) }
    }

    // MARK: Helpers

    private func store(token: String, uid: String) async {
        do {
            try await FirestoreWrite.update(reference(uid), fields: ["fcmToken": token], timeout: Self.writeTimeout)
            Logger.firebase.info("Push token stored")
        } catch {
            Logger.firebase.error("Storing the push token failed")
        }
    }

    private func unregister() async {
        try? await Messaging.messaging().deleteToken()
        await MainActor.run { UIApplication.shared.unregisterForRemoteNotifications() }
    }

    private func reference(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection(Self.usersCollection).document(uid)
    }
}
