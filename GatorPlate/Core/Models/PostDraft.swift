import Foundation

/// Editable state of the Review form. Lives in memory only; never persisted to disk.
nonisolated struct PostDraft: Equatable, Sendable {
    struct Item: Identifiable, Equatable, Sendable {
        let id: UUID
        var name: String
        var dietary: DietaryClass
        /// Only from AI; not editable.
        var calories: CalorieRange?

        init(id: UUID = UUID(), name: String = "", dietary: DietaryClass = .unknown, calories: CalorieRange? = nil) {
            self.id = id
            self.name = name
            self.dietary = dietary
            self.calories = calories
        }
    }

    struct Caution: Identifiable, Equatable, Sendable {
        let id: UUID
        var text: String

        init(id: UUID = UUID(), text: String = "") {
            self.id = id
            self.text = text
        }
    }

    var title = ""
    /// False while the title follows the auto-title; true once the user types their own.
    var titleIsCustom = false
    var description = ""
    var items: [Item] = []
    var allergens: Set<Allergen> = []
    var cautions: [Caution] = []
    var estimatedServings: Int?
    var location: PostLocation?
    /// "Room / floor / entrance". Required.
    var locationDetail = ""
    var durationMinutes = AppConfig.defaultPostDurationMinutes
    /// "+ Custom" is chosen: the length comes from the hours and minutes wheels, even when it equals a preset.
    var isCustomDuration = false
    var safetyAttested = false

    /// Empty draft for the manual path.
    init() {}

    /// Pre-filled from the sanitized AI result. Location, duration and attestation are always the user's.
    init(analysis: FoodAnalysisResult) {
        description = analysis.description
        items = analysis.items.map { Item(name: $0.name, dietary: $0.dietary, calories: $0.calories) }
        allergens = Set(analysis.allergens)
        cautions = analysis.cautions.map { Caution(text: $0) }
        estimatedServings = analysis.estimatedServings
    }

    /// Items with a name, cleaned.
    var filledItems: [FoodItem] {
        items.compactMap { item in
            let name = PostText.clean(item.name)
            return name.isEmpty ? nil : FoodItem(name: name, dietary: item.dietary, calories: item.calories)
        }
    }

    /// Cautions with text, cleaned.
    var filledCautions: [String] {
        cautions.map { PostText.clean($0.text) }.filter { !$0.isEmpty }
    }

    /// Allergens in canonical order.
    var orderedAllergens: [Allergen] {
        Allergen.allCases.filter(allergens.contains)
    }

    var overallDietary: DietaryClass {
        FoodAnalysisSanitizer.overallDietary(for: filledItems)
    }
}
