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
    /// Posts and photos are deleted this long after `expiresAt` (Firestore TTL on `deleteAt`).
    static let postRetentionHours = 24
    /// Review form limits; `firestore.rules` mirrors them (with a little headroom).
    static let postTitleMaxLength = 120
    static let postDescriptionMaxLength = 150
    /// Below this the description shows a soft warning (school best practice is 100-150).
    static let postDescriptionTargetMinLength = 100
    static let postItemNameMaxLength = 60
    static let postMaxItems = 8
    static let postCautionMaxLength = 120
    static let postMaxCautions = 4
    static let postLocationDetailMaxLength = 80
    static let postServingsRange = 1...500
    static let postReportReasonMaxLength = 200
    /// Total deadline for the post write to be confirmed by the server.
    static let postPublishTimeoutSeconds = 15
    static let postImageUploadTimeoutSeconds = 10

    // Post photos (Cloud Storage `postImages/{postId}.jpg`)
    static let postImageMaxLongEdge = 800
    static let postImageJPEGQuality = 0.6
    /// Tried in order when the photo is over the cap, first at `postImageMaxLongEdge`, then at the fallback edge.
    static let postImageFallbackQualities = [0.5, 0.4]
    static let postImageFallbackLongEdge = 640
    /// Hard cap, also enforced by `storage.rules`.
    static let postImageMaxBytes = 300_000

    /// Deadline for "Mark as gone" to be confirmed by the server.
    static let postMarkGoneTimeoutSeconds = 10

    // Live posts (map + feed)
    /// Expiry re-check without a server: expired posts drop off within this interval.
    static let postsExpiryTickSeconds = 15
    /// An empty cache snapshot waits this long for the server before the empty state shows.
    static let postsCacheGraceSeconds = 3
    /// Back in the foreground after this long, the listener restarts so its `expiresAt` bound is fresh.
    static let postsResubscribeAfterBackgroundSeconds = 300
    /// Listener retry backoff: 2, 4, 8, ... seconds, capped here.
    static let postsRetryMaxDelaySeconds = 30
    /// A post opened by ID (deep link, "View on map") waits this long to arrive before it counts as ended.
    static let postSelectionPendingSeconds = 5
    /// Photos kept in memory for the map card and the feed.
    static let postImageCacheLimit = 60
    /// Info notices on the map (e.g. "That food post has ended.") hide after this long.
    static let mapNoticeSeconds = 4

    // Directions
    /// Total deadline for an `MKDirections` walking route.
    static let routeTimeoutSeconds = 15
    /// How long Directions waits for a first location fix.
    static let routeLocationWaitSeconds = 5

    // Campus
    /// Dropped pins may sit this far outside the campus outline (sidewalks, entrances).
    static let campusPinEdgeToleranceMeters = 25.0

    // Location
    /// Key in `NSLocationTemporaryUsageDescriptionDictionary` (Info.plist).
    static let preciseLocationPurposeKey = "FoodNearby"

    // Feature flags
    /// Sprint 08: canned AI result if network/AI is down.
    static let demoFallbackEnabled = false
}
