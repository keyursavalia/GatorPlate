import Foundation

/// Sanitized output of `FoodAnalyzing`. Every field has passed `FoodAnalysisSanitizer`; nothing here is raw model output.
nonisolated struct FoodAnalysisResult: Codable, Equatable, Sendable {
    /// Just the food (no "FREE" prefix since S09). The place and time are added after the user picks them.
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
    /// Input photos that may be used (0-based, in order); people and non-food photos are left out.
    var keptPhotoIndices: [Int] = [0]
    var removedForPeople = 0
    var removedNotFood = 0

    /// No allergens reported: the UI shows "Allergen info unverified, ask the host."
    var allergensUnverified: Bool {
        allergens.isEmpty
    }
}
