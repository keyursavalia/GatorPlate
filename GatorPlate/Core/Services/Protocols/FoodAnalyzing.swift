import Foundation

@MainActor
protocol FoodAnalyzing {
    /// Content-free diagnostics of the most recent analysis.
    var lastDiagnostics: FoodAnalysisDiagnostics? { get }

    /// Analyzes a stripped JPEG from `ImagePreprocessor`. One analysis runs at a time.
    /// Throws `.cancelled` when the task is cancelled; any other error means the user falls back to manual entry.
    func analyze(jpegData: Data) async throws(AppError) -> FoodAnalysisOutcome
}
