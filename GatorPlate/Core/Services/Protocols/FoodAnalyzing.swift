import Foundation

@MainActor
protocol FoodAnalyzing {
    /// Call when the post flow opens: gets credentials (App Check) ready before the photo is taken.
    func prepare()

    /// Analyzes 1-4 stripped JPEGs from `ImagePreprocessor` of the same food, in one request. One analysis runs
    /// at a time. Photos showing people or no food are left out (`FoodAnalysisResult.keptPhotoIndices`).
    /// Throws `.cancelled` when the task is cancelled; any other error means the user falls back to manual entry.
    func analyze(photos: [Data]) async throws(AppError) -> FoodAnalysisOutcome
}

/// Multi-photo requests take longer: the total deadline grows per extra photo, capped.
nonisolated enum FoodAnalysisDeadline {
    /// `base` (`ai_timeout_seconds`) plus `aiPerExtraPhotoSeconds` per extra photo, at most `max`
    /// (`ai_max_timeout_seconds`).
    static func seconds(photoCount: Int, base: Int = AppConfig.aiTimeoutSeconds,
                        max maximum: Int = AppConfig.aiMaxTimeoutSeconds) -> Int {
        min(base + AppConfig.aiPerExtraPhotoSeconds * max(0, photoCount - 1), maximum)
    }
}
