import Foundation
import OSLog

/// Live AI analysis through Firebase AI Logic. Stub until Sprint 04.
@MainActor
final class GeminiFoodAnalyzer: FoodAnalyzing {
    func analyze(imageJPEG: Data) async throws -> FoodAnalysisResult {
        Logger.services.notice("GeminiFoodAnalyzer.analyze not implemented")
        throw AppError.aiUnavailable
    }
}
