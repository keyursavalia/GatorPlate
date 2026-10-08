import Foundation
import Synchronization

/// Thrown by `awaitCompletion` when the deadline passes before the completion handler runs.
nonisolated struct DeadlineExceeded: Error {}

/// Bridges a completion-handler API to async with a total deadline. Whichever comes first, the
/// completion or the deadline, resumes the caller; the other is ignored. Runs on the caller's actor.
func awaitCompletion(deadlineSeconds: Int,
                     isolation: isolated (any Actor)? = #isolation,
                     _ start: (@escaping @Sendable (Error?) -> Void) -> Void) async throws {
    let once = ResumeOnce()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        start { error in
            guard once.claim() else { return }
            if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
        Task {
            try? await Task.sleep(for: .seconds(deadlineSeconds))
            guard once.claim() else { return }
            continuation.resume(throwing: DeadlineExceeded())
        }
    }
}

private nonisolated final class ResumeOnce: Sendable {
    private let isClaimed = Mutex(false)

    /// True for the first caller only.
    func claim() -> Bool {
        isClaimed.withLock { isClaimed in
            guard !isClaimed else { return false }
            isClaimed = true
            return true
        }
    }
}
