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

    /// Post content limits. The title and image caps mirror `firestore.rules`.
    static let maxTitleLength = 120
    static let recommendedDescriptionLength = 100
    static let maxDescriptionLength = 150
    static let maxFoodItems = 12
    static let maxItemNameLength = 60
    static let maxCautions = 5
    static let maxCautionLength = 120
    static let maxRoomDetailLength = 80
    static let maxServings = 500
    /// Hard cap for a stored photo (Firestore documents are limited to 1 MiB).
    static let maxImageBytes = 300_000
    /// Posts and photos are removed this long after `expiresAt` (Firestore TTL on `deleteAt`).
    static let postRetentionSeconds = 24 * 60 * 60
    /// Publishing gives up and reports `.network` after this long without a server acknowledgement.
    static let publishTimeoutSeconds = 10
    /// `buildingId` stored when the poster drops a pin instead of choosing a building.
    static let customPinBuildingId = "custom-pin"
    static let customPinLocationName = "Pinned spot on campus"
    /// Sprint 8: canned AI result if the network or AI is down.
    static let demoFallbackEnabled = false
}
