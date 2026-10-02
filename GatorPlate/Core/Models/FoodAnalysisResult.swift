import Foundation

/// Sanitized output of a photo analysis. Sprint 4 finalizes the decoding and validation
/// rules in `docs/04-AI-GEMINI-SPEC.md`; this is the shape the rest of the app depends on.
nonisolated struct FoodAnalysisResult: Equatable, Sendable {
    var title: String
    var description: String
    var items: [FoodItem]
    var overallDietary: DietaryClass
    var allergenWarnings: [Allergen]
    var cautions: [String]
    var estimatedServings: Int?
}
