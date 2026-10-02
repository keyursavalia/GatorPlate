import Foundation
import os

/// Client-side anti-spam: remembers when this session last published. In memory only, never persisted.
nonisolated final class PostCooldown: Sendable {
    private let lastPublished = OSAllocatedUnfairLock<Date?>(initialState: nil)
    private let seconds: Int

    init(seconds: Int = AppConfig.postCooldownSeconds) {
        self.seconds = seconds
    }

    func recordPublish(at date: Date = Date()) {
        lastPublished.withLock { $0 = date }
    }

    /// Whole seconds left before another post is allowed (0 when allowed).
    func remainingSeconds(now: Date = Date()) -> Int {
        guard let last = lastPublished.withLock({ $0 }) else { return 0 }
        let remaining = Double(seconds) - now.timeIntervalSince(last)
        return remaining > 0 ? Int(remaining.rounded(.up)) : 0
    }
}
