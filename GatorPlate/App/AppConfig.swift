import Foundation

/// Single source of truth for constants and feature flags. No magic numbers elsewhere.
nonisolated enum AppConfig {
    static let appName = "GatorPlate"
    static let allowedEmailDomains = ["sfsu.edu", "mail.sfsu.edu"]
    /// DEMO MODE: email verification is not enforced.
    static let requireEmailVerification = false
    static let termsVersion = "2026-10-demo-1"
    /// Placeholders substituted into the bundled Terms of Use. Replace before any public demo.
    static let teamName = "[TEAM NAME]"
    static let contactEmail = "[CONTACT EMAIL]"

    /// Auth form limits.
    static let minPasswordLength = 8
    static let maxDisplayNameLength = 50
    static let maxOrgNameLength = 60

    /// Launch argument that forces mock services and skips Firebase (UI tests).
    static let uiTestMockArgument = "-UITestMock"

    /// Verified against the Firebase AI Logic model list on 2026-10-02 (stable, structured output + image input).
    /// Fallback if it is ever retired: `gemini-3.5-flash`. This is the only place the name is written.
    static let geminiModelName = "gemini-3.8-flash"
    static let aiTimeoutSeconds = 25
    /// Below this model confidence an analysis is rejected as "not food".
    static let aiMinConfidence = 0.4
    static let aiMaxImageLongEdge = 1024
    static let aiJPEGQuality = 0.7

    /// `@AppStorage` key: the "Photograph the food, not people." hint shows until the camera has been used once.
    static let cameraHintSeenKey = "cameraHintSeen"

    static let postDurationOptionsMinutes = [15, 30, 45, 60]
    static let defaultPostDurationMinutes = 30
    static let maxPostDurationMinutes = 60
    /// Client-side anti-spam.
    static let postCooldownSeconds = 60
    /// Sprint 8: canned AI result if the network or AI is down.
    static let demoFallbackEnabled = false
}
