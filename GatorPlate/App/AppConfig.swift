import Foundation

/// Single source of truth for constants and feature flags. No magic numbers elsewhere.
nonisolated enum AppConfig {
    static let appName = "GatorPlate"
    static let allowedEmailDomains = ["sfsu.edu", "mail.sfsu.edu"]
    /// DEMO MODE: email verification is not enforced.
    static let requireEmailVerification = false
    static let termsVersion = "2026-10-demo-1"

    /// Placeholder; verify the current Flash model in the Firebase AI Logic docs in Sprint 4.
    static let geminiModelName = "gemini-2.5-flash"
    static let aiTimeoutSeconds = 25
    static let aiMaxImageLongEdge = 1024
    static let aiJPEGQuality = 0.7

    static let postDurationOptionsMinutes = [15, 30, 45, 60]
    static let defaultPostDurationMinutes = 30
    static let maxPostDurationMinutes = 60
    /// Client-side anti-spam.
    static let postCooldownSeconds = 60
    /// Sprint 8: canned AI result if the network or AI is down.
    static let demoFallbackEnabled = false
}
