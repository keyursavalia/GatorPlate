import Foundation

/// The "Custom notifications" row in Settings: which categories are in use, shown as icons. Empty = all free food.
nonisolated enum AlertFilterSummary {
    enum Category: String, CaseIterable, Sendable {
        case diet, places, foods, allergens

        /// SF Symbol shown in the Settings row.
        var symbol: String {
            switch self {
            case .diet: "leaf.fill"
            case .places: "mappin"
            case .foods: "heart.fill"
            case .allergens: "exclamationmark.triangle.fill"
            }
        }

        var name: String {
            switch self {
            case .diet: "diet"
            case .places: "places"
            case .foods: "favorite foods"
            case .allergens: "allergens"
            }
        }
    }

    /// Categories the saved filters use, in a fixed order; empty when notifications are for all free food.
    static func categories(for filters: AlertFilters?) -> [Category] {
        guard let filters = AlertFilterMatcher.effective(filters) else { return [] }
        return Category.allCases.filter { category in
            switch category {
            case .diet: !filters.diets.isEmpty
            case .places: !filters.places.isEmpty
            case .foods: !filters.foods.isEmpty
            case .allergens: !filters.avoidAllergens.isEmpty || filters.skipUnverifiedAllergens
            }
        }
    }

    /// "All free food" or "Custom: diet, places", for VoiceOver.
    static func spoken(for filters: AlertFilters?) -> String {
        let categories = categories(for: filters)
        return categories.isEmpty ? "All free food" : "Custom: " + categories.map(\.name).joined(separator: ", ")
    }
}
