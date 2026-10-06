import Foundation

/// Single source of truth for constants and feature flags. No magic numbers elsewhere.
nonisolated enum AppConfig {
    static let appName = "GatorPlate"

    // Auth
    static let allowedEmailDomains = ["gmail.com", "outlook.com", "icloud.com"]
    static let requireEmailVerification = true
    static let termsVersion = "2026-10-demo-1"

    // AI (Firebase AI Logic)
    /// Placeholder; verify the current Flash model name in the Firebase AI Logic docs (Sprint 04).
    static let geminiModelName = "gemini-2.5-flash"
    static let aiTimeoutSeconds = 25
    static let aiMaxImageLongEdge = 1024
    static let aiJPEGQuality = 0.7

    // Posts
    static let postDurationOptionsMinutes = [15, 30, 45, 60]
    static let defaultPostDurationMinutes = 30
    static let maxPostDurationMinutes = 60
    /// Client-side anti-spam.
    static let postCooldownSeconds = 60

    // Feature flags
    /// Sprint 08: canned AI result if network/AI is down.
    static let demoFallbackEnabled = false
}
