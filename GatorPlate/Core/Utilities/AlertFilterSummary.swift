import Foundation

/// The plain-language sentence at the top of "What to alert me about", built from the filters (and announced to
/// VoiceOver), e.g. "You'll get alerts for vegetarian food at the Library or Chavez Center, without peanuts."
nonisolated enum AlertFilterSummary {
    static func sentence(for filters: AlertFilters?) -> String {
        guard let filters = AlertFilterMatcher.effective(filters) else {
            return "You'll get alerts for all free food on campus."
        }
        var sentence = "You'll get alerts for \(dietPhrase(filters))"
        if !filters.foods.isEmpty {
            sentence += " like \(orList(filters.foods))"
        }
        if filters.places.isEmpty {
            sentence += " anywhere on campus"
        } else {
            let names = filters.places.map { CampusBuilding.byId($0).map(placeName) ?? $0 }
            sentence += " at \(orList(names))"
        }
        if !filters.avoidAllergens.isEmpty {
            sentence += ", without \(orList(filters.avoidAllergens.map { $0.displayName.lowercased() }))"
        }
        if filters.skipUnverifiedAllergens {
            sentence += filters.avoidAllergens.isEmpty ? ", only when allergens are listed" : " and only when allergens are listed"
        }
        return sentence + "."
    }

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

    private static func dietPhrase(_ filters: AlertFilters) -> String {
        let base: String
        if filters.diets.contains(.vegetarian) {
            base = "vegetarian food"
        } else if filters.diets.contains(.vegan) {
            base = "vegan food"
        } else {
            return "free food"
        }
        return filters.includeUnknownDiet ? "\(base) (or diet unknown)" : base
    }

    private static func placeName(_ building: CampusBuilding) -> String {
        building.id == "library" ? "the Library" : building.shortName
    }

    /// "A", "A or B", "A, B or C".
    static func orList(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " or " + (items.last ?? "")
        }
    }
}
