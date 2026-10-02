import Foundation

nonisolated enum RejectionReason: Equatable, Sendable {
    case notFood
    case containsPeople
    case lowConfidence
    /// The model's safety filters blocked the photo or the response.
    case blocked
}

/// A rejection is a normal result of analysis (the user retakes or types it in), not an error.
nonisolated enum FoodAnalysisOutcome: Equatable, Sendable {
    case accepted(FoodAnalysisResult)
    case rejected(RejectionReason)
}
