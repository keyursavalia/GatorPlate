import Foundation

/// Why a photo can't be turned into a post. Rejections are outcomes, not errors: the user retakes or fills it in.
nonisolated enum FoodAnalysisRejection: String, Equatable, Sendable {
    case notFood
    case containsPeople
    case lowConfidence
}

nonisolated enum FoodAnalysisOutcome: Equatable, Sendable {
    case accepted(FoodAnalysisResult)
    case rejected(FoodAnalysisRejection)
}

/// Content-free facts about the last analysis, for logs and the DEBUG evaluation line.
nonisolated struct FoodAnalysisDiagnostics: Equatable, Sendable {
    var latencyMs: Int
    var attempts: Int
    /// Outcome or error category, e.g. "accepted", "notFood", "timeout", "rate_limited".
    var category: String
    /// The model's own overallDietary, kept only to measure how often local logic overrides it.
    var modelDietary: String?
    var modelConfidence: Double?
}
