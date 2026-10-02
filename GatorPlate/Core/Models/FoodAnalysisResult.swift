import Foundation

/// Sanitized, accepted output of a photo analysis (see `FoodAnalysisSanitizer`). Rejections are
/// represented by `FoodAnalysisOutcome.rejected`, never by a half-filled result.
nonisolated struct FoodAnalysisResult: Equatable, Sendable {
    var title: String
    var description: String
    var items: [FoodItem]
    var overallDietary: DietaryClass
    var allergenWarnings: [Allergen]
    var cautions: [String]
    var estimatedServings: Int?
    /// True when the model reported no allergens: the UI says "Allergen info unverified, ask the host."
    var allergensUnverified = false
}
