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
