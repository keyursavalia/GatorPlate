import Foundation

/// AI must never block posting: callers fall back to manual entry when this throws or rejects.
nonisolated protocol FoodAnalyzing: Sendable {
    /// - Throws: `AppError` for failures, `CancellationError` when the calling task is cancelled.
    ///   A photo the model declines (not food, people, blocked) is a `.rejected` outcome, not a throw.
    func analyze(imageJPEG: Data) async throws -> FoodAnalysisOutcome
}
