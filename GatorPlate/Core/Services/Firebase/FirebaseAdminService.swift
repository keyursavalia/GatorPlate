import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import OSLog

/// Admin moderation on Firestore. Reads need the `admin` claim (`firestore.rules`); actions are `adminActions` docs
/// processed by `onAdminActionCreated`. Logs outcomes only, never report text, names or uids.
@MainActor
final class FirebaseAdminService: AdminService {
    private var database: Firestore { Firestore.firestore() }

    func refreshAdminStatus() async -> Bool {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return false }
        let callable = Functions.functions(region: AppConfig.functionsRegion).httpsCallable("syncAdminClaim")
        callable.timeoutInterval = TimeInterval(AppConfig.adminSyncTimeoutSeconds)
        do {
            _ = try await callable.call()
        } catch {
            Logger.services.error("Admin claim sync failed: \((error as NSError).code, privacy: .public)")
        }
        // A fresh token carries the claim the server just set (or removed).
        let isAdmin = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            user.getIDTokenResult(forcingRefresh: true) { result, _ in
                continuation.resume(returning: result?.claims["admin"] as? Bool == true)
            }
        }
        Logger.services.info("Admin status: \(isAdmin, privacy: .public)")
        return isAdmin
    }

    func observeAppeals() -> AsyncThrowingStream<[AdminAppeal], Error> {
        let query = database.collection("appeals").order(by: "createdAt", descending: true)
            .limit(to: AppConfig.adminListLimit)
        return Self.stream(query) { document in
            let data = document.data(with: .estimate)
            guard let message = data["message"] as? String,
                  let bannedUntil = (data["bannedUntil"] as? Timestamp)?.dateValue() else { return nil }
            return AdminAppeal(uid: document.documentID, message: message, bannedUntil: bannedUntil,
                               createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                               resolution: (data["resolution"] as? String).flatMap(AppealResolution.init),
                               resolutionNote: data["resolutionNote"] as? String)
        }
    }

    func observeReports() -> AsyncThrowingStream<[AdminReport], Error> {
        let since = Date.now.addingTimeInterval(-Double(AppConfig.reportRetentionDays) * 86_400)
        let query = database.collection("reports")
            .whereField("createdAt", isGreaterThan: Timestamp(date: since))
            .order(by: "createdAt", descending: true)
            .limit(to: AppConfig.adminListLimit)
        return Self.stream(query) { document in
            let data = document.data(with: .estimate)
            guard let postId = data["postId"] as? String,
                  let category = (data["category"] as? String).flatMap(ReportCategory.init) else { return nil }
            return AdminReport(id: document.documentID, postId: postId, category: category,
                               reason: data["reason"] as? String,
                               createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                               snapshot: Self.snapshot(data["postSnapshot"] as? [String: Any]),
                               aiVerdict: data["aiVerdict"] as? String, aiConcern: data["aiConcern"] as? String,
                               aiRationale: data["aiRationale"] as? String)
        }
    }

    func moderation(uid: String) async throws -> AdminModeration? {
        let document = database.collection("moderation").document(uid)
        let snapshot: DocumentSnapshot
        do {
            snapshot = try await document.getDocument()
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        guard let data = snapshot.data() else { return nil }
        let removals = (data["removals"] as? [[String: Any]] ?? []).compactMap { item -> AdminModeration.Removal? in
            guard let postId = item["postId"] as? String, let category = item["category"] as? String,
                  let atMs = item["atMs"] as? Double else { return nil }
            return AdminModeration.Removal(postId: postId, category: category,
                                           removedAt: Date(timeIntervalSince1970: atMs / 1000))
        }
        return AdminModeration(removals: removals.sorted { $0.removedAt > $1.removedAt },
                               bannedUntil: (data["bannedUntil"] as? Timestamp)?.dateValue(),
                               blockedByCount: data["blockedByCount"] as? Int ?? 0)
    }

    func run(_ action: AdminActionRequest) async throws -> AdminActionOutcome {
        guard let uid = Auth.auth().currentUser?.uid else { throw AppError.unauthorized }
        var fields = action.fields
        fields["createdBy"] = uid
        fields["createdAt"] = FieldValue.serverTimestamp()
        let document = database.collection("adminActions").document()
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.accountWriteTimeoutSeconds) { completion in
                document.setData(fields) { completion($0) }
            }
        } catch is DeadlineExceeded {
            throw AppError.network
        } catch {
            throw FirebaseErrorMapper.map(error)
        }
        let outcome = await Self.waitForStatus(document)
        let state = outcome?.succeeded == true ? "done" : "failed or pending"
        Logger.services.info("Admin action finished: \(state, privacy: .public)")
        return outcome ?? AdminActionOutcome(succeeded: false,
                                             message: "Still processing. Check again in a minute.")
    }

    // MARK: Helpers

    private nonisolated static func snapshot(_ data: [String: Any]?) -> ReportPostSnapshot? {
        guard let data else { return nil }
        let org = (data["orgName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return ReportPostSnapshot(title: data["title"] as? String ?? "",
                                  description: data["description"] as? String ?? "",
                                  locationName: data["locationName"] as? String ?? "",
                                  authorUid: data["authorUid"] as? String ?? "",
                                  authorName: data["authorName"] as? String ?? "", orgName: org)
    }

    /// The function's `status` (done / failed) and `result`, or nil if it didn't finish within the deadline.
    private static func waitForStatus(_ document: DocumentReference) async -> AdminActionOutcome? {
        let stream = AsyncStream<AdminActionOutcome> { continuation in
            let registration = document.addSnapshotListener { snapshot, _ in
                guard let status = snapshot?.get("status") as? String, status == "done" || status == "failed" else {
                    return
                }
                continuation.yield(AdminActionOutcome(succeeded: status == "done",
                                                      message: snapshot?.get("result") as? String ?? status))
                continuation.finish()
            }
            let handle = AdminListenerHandle(registration)
            let timeout = Task {
                try? await Task.sleep(for: .seconds(AppConfig.adminActionTimeoutSeconds))
                continuation.finish()
            }
            continuation.onTermination = { _ in
                handle.remove()
                timeout.cancel()
            }
        }
        for await outcome in stream {
            return outcome
        }
        return nil
    }

    private static func stream<T: Sendable>(_ query: Query,
                                            _ map: @escaping @Sendable (QueryDocumentSnapshot) -> T?)
        -> AsyncThrowingStream<[T], Error> {
        AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: FirebaseErrorMapper.map(error))
                    return
                }
                continuation.yield((snapshot?.documents ?? []).compactMap(map))
            }
            let handle = AdminListenerHandle(registration)
            continuation.onTermination = { _ in handle.remove() }
        }
    }
}

private nonisolated final class AdminListenerHandle: @unchecked Sendable {
    private let registration: any ListenerRegistration

    init(_ registration: any ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}
