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
    /// 2026-10-14: switched from gemini-3.5-flash, which Google deprecated; 3.6 Flash is active.
    /// Never hardcode the model name elsewhere.
    static let geminiModelName = "gemini-3.6-flash"
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
    /// Analyzing screen: the "Still working..." threshold.
    static let aiSlowThresholdSeconds = 10
    /// With this many photos or more, each is downscaled to `aiMultiPhotoLongEdge` (fewer image tokens).
    static let aiMultiPhotoDownscaleThreshold = 3
    static let aiMultiPhotoLongEdge = 768
    /// The deadline grows by this much per extra photo, up to `aiMaxTimeoutSeconds`.
    static let aiPerExtraPhotoSeconds = 4
    static let aiMaxTimeoutSeconds = 35
    /// Analyzing checklist: a step is checked off this often until the result arrives.
    static let aiChecklistStepSeconds = 2.0

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
    /// Report reason (required for "Unsafe to eat", one or two sentences). `firestore.rules` and the
    /// `onReportCreated` function mirror these.
    static let reportReasonMinLength = 20
    static let reportReasonMaxLength = 280
    /// A banned poster's appeal (`appeals/{uid}`).
    static let appealMinLength = 20
    static let appealMaxLength = 500
    /// Total deadline for the post write to be confirmed by the server.
    static let postPublishTimeoutSeconds = 15
    static let postImageUploadTimeoutSeconds = 10

    // Post photos (Cloud Storage `postImages/{postId}.jpg` for the cover, `{postId}_{slot}.jpg` for slots 1-3)
    /// Photos per post, camera and library combined. `storage.rules` and `firestore.rules` allow slots 0-3.
    static let postMaxPhotos = 4
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
    /// A post opened from an alert waits at most this long for the listener (a resumed app may need to reconnect).
    static let alertOpenMaxWaitSeconds = 20
    /// A tapped alert's post is looked up once on the server (so "no longer available" shows at once).
    static let alertLookupTimeoutSeconds = 5
    /// The "no longer available" card hides after this long (not while VoiceOver is on it).
    static let alertUnavailableCardSeconds = 10.0
    /// Latitude span of the map region shown when an alert opens a post; the pin sits above the sheet.
    static let alertOpenRegionSpanDegrees = 0.006
    /// Photos kept in memory for the map card and the feed.
    static let postImageCacheLimit = 60
    /// Map pins show the post's cover photo (diet ring + badge); false keeps the glyph pins.
    static let mapPhotoPins = true
    /// 44 pt @3x.
    static let mapPinThumbnailPixels = 132
    static let mapPinThumbnailCacheLimit = 120
    /// Info notices on the map (e.g. "That food post has ended.") hide after this long.
    static let mapNoticeSeconds = 4

    // Notifications (FCM per-device installation IDs; the `onPostCreated` Cloud Function sends the alerts)
    /// Data payload key for the post to open. The function writes the same key.
    static let notificationPostIdKey = "postId"
    /// Deadline for `Messaging.register`.
    static let notificationRegisterTimeoutSeconds = 10
    static let notificationWriteTimeoutSeconds = 10
    /// Sign-out waits at most this long to remove the installation ID.
    static let notificationSignOutTimeoutSeconds = 5
    /// Quiet hours, campus time (America/Los_Angeles). `functions/src/recipients.ts` mirrors these.
    static let quietHoursStartHour = 23
    static let quietHoursEndHour = 7

    // Alert filters (users/{uid}.alertFilters; `functions/src/filters.ts` mirrors these limits)
    static let alertFilterMaxPlaces = 15
    static let alertFilterMaxFoods = 10
    static let alertFilterFoodMaxLength = 30

    // Map/Feed filter (device only: `PostFilterStore`, UserDefaults per uid)
    /// "Time left" choices besides Any: at least this many minutes left.
    static let browseFilterMinutesLeftOptions = [10, 20]
    /// "Distance" choices besides Any: at most this many minutes' walk.
    static let browseFilterWalkMinutesOptions = [5, 10, 15]
    /// A new location fix re-filters only after moving this far (no work on every fix).
    static let browseLocationChangeMeters = 25.0
    /// "Showing 3 of 7 posts" is announced this long after the last change.
    static let browseAnnouncementDelaySeconds = 1.0

    // Account
    /// "Resend link" in Forgot password is disabled this long after each send.
    static let passwordResetResendSeconds = 60
    /// The server requires a sign-in this recent to delete an account (`auth_time`).
    static let accountRecentLoginSeconds = 300
    /// Deadline for the delete-account callable.
    static let accountDeleteTimeoutSeconds = 30
    static let accountWriteTimeoutSeconds = 10
    /// Cloud Functions region (matches Firestore nam5 and `onPostCreated`).
    static let functionsRegion = "us-central1"

    // First-run permissions (location, then notifications, on the first Map appearance)
    /// The campus map renders before the location prompt.
    static let permissionSettleSeconds = 0.6
    /// Pause between the location answer and the notification prompt.
    static let permissionGapSeconds = 1.0
    /// The camera prompt waits for the post-flow cover to finish presenting.
    static let cameraPromptDelaySeconds = 0.35
    /// "Starting camera" shows only if the session takes longer than this.
    static let cameraSpinnerDelaySeconds = 0.3
    /// Map toasts (e.g. "Alerts on for all free food") hide after this long.
    static let toastSeconds = 6.0

    // Campus
    /// Dropped pins may sit this far outside the campus outline (sidewalks, entrances).
    static let campusPinEdgeToleranceMeters = 25.0

    // Map camera (north visible edge stops at Stonestown; see `CampusViewport`)
    /// `false` keeps the static center bounds and relies on the rubber band alone.
    static let mapAdaptiveCenterBounds = true
    /// The visible north edge may pass the limit by this much before the camera is moved back.
    static let mapNorthToleranceMeters = 10.0
    /// The correction moves this much further south than the excess, so its own check passes.
    static let mapCorrectionPaddingMeters = 5.0

    // Location
    /// Key in `NSLocationTemporaryUsageDescriptionDictionary` (Info.plist).
    static let preciseLocationPurposeKey = "FoodNearby"

    // Feature flags
    /// Sprint 08: canned AI result if network/AI is down.
    static let demoFallbackEnabled = false
}
