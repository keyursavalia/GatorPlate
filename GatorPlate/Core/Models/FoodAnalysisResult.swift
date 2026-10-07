import Foundation

/// Sanitized output of `FoodAnalyzing`. Every field has passed `FoodAnalysisSanitizer`; nothing here is raw model output.
nonisolated struct FoodAnalysisResult: Codable, Equatable, Sendable {
    /// Starts with "FREE: ". The location is appended after the user picks it (Sprint 05).
    var title: String
    var description: String
    var items: [FoodItem]
    /// Recomputed locally from `items`; the model's own value is never used.
    var overallDietary: DietaryClass
    /// Likely allergens ("May contain"), never a guarantee.
    var allergens: [Allergen]
    var cautions: [String]
    var estimatedServings: Int?
    var confidence: Double
    var promptVersion: String
    var modelName: String

    /// No allergens reported: the UI shows "Allergen info unverified, ask the host."
    var allergensUnverified: Bool {
        allergens.isEmpty
    }
}
