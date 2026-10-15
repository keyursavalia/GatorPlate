import Foundation

@MainActor
protocol FoodAnalyzing {
    /// Content-free diagnostics of the most recent analysis.
    var lastDiagnostics: FoodAnalysisDiagnostics? { get }

    /// Call when the post flow opens: gets credentials (App Check) ready before the photo is taken.
    func prepare()

    /// Analyzes 1-4 stripped JPEGs from `ImagePreprocessor` of the same food, in one request. One analysis runs
    /// at a time. Photos showing people or no food are left out (`FoodAnalysisResult.keptPhotoIndices`).
    /// Throws `.cancelled` when the task is cancelled; any other error means the user falls back to manual entry.
    func analyze(photos: [Data]) async throws(AppError) -> FoodAnalysisOutcome
}

/// Multi-photo requests take longer: the total deadline grows per extra photo, capped.
nonisolated enum FoodAnalysisDeadline {
    /// `aiTimeoutSeconds` plus `aiPerExtraPhotoSeconds` per extra photo, at most `aiMaxTimeoutSeconds`.
    static func seconds(photoCount: Int) -> Int {
        min(AppConfig.aiTimeoutSeconds + AppConfig.aiPerExtraPhotoSeconds * max(0, photoCount - 1),
            AppConfig.aiMaxTimeoutSeconds)
    }
}
