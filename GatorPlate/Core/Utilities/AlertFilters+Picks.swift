import Foundation

/// Editing the diet, place, allergen and food picks. Shared by Custom notifications and the Map/Feed filter (which
/// edits its picks through `PostFilter.picks`), so both behave the same way.
nonisolated extension AlertFilters {
    static let foodSuggestions = ["Pizza", "Boba", "Coffee", "Dessert", "Snacks", "Fruit"]

    /// Why a food couldn't be added.
    enum FoodError: Error, Equatable {
        case tooLong, tooMany

        var message: String {
            switch self {
            case .tooLong: "Keep it under \(AppConfig.alertFilterFoodMaxLength) characters."
            case .tooMany: "Up to \(AppConfig.alertFilterMaxFoods) foods."
            }
        }
    }

    /// Any category picked (diet, place, food, allergen, or "skip posts with no allergen info").
    var hasPicks: Bool {
        !diets.isEmpty || !places.isEmpty || !foods.isEmpty || !avoidAllergens.isEmpty || skipUnverifiedAllergens
    }

    mutating func clearPicks() {
        diets = []
        includeUnknownDiet = false
        places = []
        foods = []
        avoidAllergens = []
        skipUnverifiedAllergens = false
    }

    mutating func toggle(_ diet: Diet) {
        Self.toggle(diet, in: &diets)
    }

    mutating func toggle(_ allergen: Allergen) {
        let wasEmpty = avoidAllergens.isEmpty
        Self.toggle(allergen, in: &avoidAllergens)
        // Suggested on when the student starts avoiding something; they can turn it off.
        if wasEmpty, !avoidAllergens.isEmpty { skipUnverifiedAllergens = true }
    }

    mutating func setPlaces(_ ids: [String]) {
        places = Array(ids.prefix(AppConfig.alertFilterMaxPlaces))
    }

    mutating func removePlace(_ id: String) {
        places.removeAll { $0 == id }
    }

    /// True when added. Trimmed, 1-30 characters, at most 10, no duplicates (case-insensitive).
    @discardableResult
    mutating func addFood(_ raw: String) throws(FoodError) -> Bool {
        let food = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !food.isEmpty else { return false }
        guard food.count <= AppConfig.alertFilterFoodMaxLength else { throw .tooLong }
        guard foods.count < AppConfig.alertFilterMaxFoods else { throw .tooMany }
        guard !isFoodSelected(food) else { return false }
        foods.append(food)
        return true
    }

    mutating func removeFood(_ food: String) {
        foods.removeAll { $0.caseInsensitiveCompare(food) == .orderedSame }
    }

    func isFoodSelected(_ food: String) -> Bool {
        foods.contains { $0.caseInsensitiveCompare(food) == .orderedSame }
    }

    mutating func toggleFood(_ food: String) {
        if isFoodSelected(food) { removeFood(food) } else { _ = try? addFood(food) }
    }

    /// Suggestions first, then the student's own foods, each once.
    var foodRows: [String] {
        let custom = foods.filter { food in
            !Self.foodSuggestions.contains { $0.caseInsensitiveCompare(food) == .orderedSame }
        }
        return Self.foodSuggestions + custom
    }

    private static func toggle<T: Equatable>(_ value: T, in list: inout [T]) {
        if let index = list.firstIndex(of: value) {
            list.remove(at: index)
        } else {
            list.append(value)
        }
    }
}
