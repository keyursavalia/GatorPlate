import Foundation

/// AI must never block posting: callers fall back to manual entry when this throws.
nonisolated protocol FoodAnalyzing: Sendable {
    func analyze(imageJPEG: Data) async throws -> FoodAnalysisResult
}
