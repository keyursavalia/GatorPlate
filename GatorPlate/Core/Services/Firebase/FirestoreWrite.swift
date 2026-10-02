import FirebaseFirestore
import Foundation
import os

/// Firestore queues writes while offline and only acknowledges them once the server does, so a plain
/// `await setData` can hang for as long as the device is offline. This races the acknowledgement against a timer
/// and reports `.network` on timeout. A write that timed out can still land later: ids are stable and `setData`
/// overwrites, so a retry is idempotent.
nonisolated enum FirestoreWrite {
    private final class Once: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock(initialState: false)
        /// True only for the first caller.
        func claim() -> Bool { lock.withLock { done in
            if done { return false }
            done = true
            return true
        } }
    }

    static func set(_ reference: DocumentReference, data: [String: Any], timeout: Duration) async throws {
        let once = Once()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            reference.setData(data) { error in
                guard once.claim() else { return }
                if let error {
                    continuation.resume(throwing: FirestoreErrorMapping.map(error))
                } else {
                    continuation.resume()
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                guard once.claim() else { return }
                continuation.resume(throwing: AppError.network)
            }
        }
    }

    static func update(_ reference: DocumentReference, fields: [AnyHashable: Any], timeout: Duration) async throws {
        let once = Once()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            reference.updateData(fields) { error in
                guard once.claim() else { return }
                if let error {
                    continuation.resume(throwing: FirestoreErrorMapping.map(error))
                } else {
                    continuation.resume()
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                guard once.claim() else { return }
                continuation.resume(throwing: AppError.network)
            }
        }
    }
}

nonisolated enum FirestoreErrorMapping {
    static func map(_ error: any Error) -> AppError {
        if let appError = error as? AppError { return appError }
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else { return .unknown }
        switch FirestoreErrorCode.Code(rawValue: nsError.code) {
        case .unavailable, .deadlineExceeded: return .network
        case .permissionDenied: return .permissionDenied
        case .unauthenticated: return .unauthorized
        default: return .unknown
        }
    }
}
