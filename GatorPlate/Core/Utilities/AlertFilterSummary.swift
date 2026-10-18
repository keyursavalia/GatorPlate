import Foundation

/// Short summary of "Custom notifications" for the Settings row.
nonisolated enum AlertFilterSummary {
    /// Short summary for the Settings row, e.g. "Vegetarian · 2 places" or "All free food".
    static func short(for filters: AlertFilters?) -> String {
        guard let filters = AlertFilterMatcher.effective(filters) else { return "All free food" }
        var parts: [String] = []
        if filters.diets.contains(.vegetarian) {
            parts.append("Vegetarian")
        } else if filters.diets.contains(.vegan) {
            parts.append("Vegan")
        }
        if !filters.places.isEmpty {
            parts.append(filters.places.count == 1 ? "1 place" : "\(filters.places.count) places")
        }
        if !filters.foods.isEmpty {
            parts.append(filters.foods.count == 1 ? "1 food" : "\(filters.foods.count) foods")
        }
        if !filters.avoidAllergens.isEmpty {
            parts.append("avoids \(filters.avoidAllergens.count)")
        }
        return parts.isEmpty ? "All free food" : parts.joined(separator: " · ")
    }
}
