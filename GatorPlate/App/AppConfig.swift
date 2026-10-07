import Foundation

/// Single source of truth for constants and feature flags. No magic numbers elsewhere.
nonisolated enum AppConfig {
    static let appName = "GatorPlate"

    // Auth
    static let allowedEmailDomains = ["gmail.com", "outlook.com", "icloud.com"]
    static let requireEmailVerification = true
    static let termsVersion = "2026-10-demo-1"
    static let minPasswordLength = 8
    static let maxNameLength = 60
    static let maxEmailLength = 254
    /// Substituted for [TEAM NAME] / [CONTACT EMAIL] in the Terms. Empty keeps the bracketed placeholder visible.
    static let teamName = ""
    static let contactEmail = ""

    // AI (Firebase AI Logic)
    /// Verified 2026-10-07 in the Firebase AI Logic models page: stable, image input + JSON schema,
    /// retirement no earlier than 2027-05-19. Never hardcode the model name elsewhere.
    static let geminiModelName = "gemini-3.5-flash"
    /// `true` uses thinking level `.minimal` (faster; not supported on 3.7/3.8 Flash), `false` the default `.low`.
    static let aiThinkingMinimal = false
    static let aiTemperature: Float = 0.2
    /// Covers thinking tokens plus the JSON answer.
    static let aiMaxOutputTokens = 2048
    static let aiTimeoutSeconds = 25
    static let aiRetryDelaySeconds = 1
    static let aiMaxImageLongEdge = 1024
    static let aiJPEGQuality = 0.7
    /// Below this the result is rejected as "couldn't tell what this is".
    static let aiMinConfidence = 0.4
    static let aiTitleMaxLength = 80
    static let aiDescriptionMaxLength = 150
    static let aiItemNameMaxLength = 60
    static let aiCautionMaxLength = 120
    static let aiMaxItems = 8
    static let aiMaxCautions = 4
    static let aiMaxCalories = 3000
    static let aiServingsRange = 1...500
    /// Analyzing screen: status line rotation and the "Still working..." threshold.
    static let aiStatusRotationSeconds = 1.5
    static let aiSlowThresholdSeconds = 10

    // Posts
    static let postDurationOptionsMinutes = [15, 30, 45, 60]
    static let defaultPostDurationMinutes = 30
    static let maxPostDurationMinutes = 60
    /// Client-side anti-spam.
    static let postCooldownSeconds = 60

    // Location
    /// Key in `NSLocationTemporaryUsageDescriptionDictionary` (Info.plist).
    static let preciseLocationPurposeKey = "FoodNearby"

    // Feature flags
    /// Sprint 08: canned AI result if network/AI is down.
    static let demoFallbackEnabled = false
}
