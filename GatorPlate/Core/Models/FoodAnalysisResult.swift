import Foundation

/// Validated output of `FoodAnalyzing`. Sprint 04 may refine this against the AI spec.
nonisolated struct FoodAnalysisResult: Codable, Sendable {
    var title: String
    var description: String
    var items: [FoodItem]
    var overallDietary: DietaryClass
    var allergenWarnings: [Allergen]
    var cautions: [String]
    var estimatedServings: Int?
}
