import Foundation

@MainActor
protocol FoodAnalyzing {
    /// Analyzes a resized JPEG. Throws `AppError.aiUnavailable` on failure; callers must fall back to manual entry.
    func analyze(imageJPEG: Data) async throws -> FoodAnalysisResult
}
