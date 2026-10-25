import Foundation

/// Mirror of `functions/src/filters.ts` `matchesFilters`, so the Map/Feed filter (`PostFilterMatcher`) answers exactly
/// like Custom notifications. Both run the shared fixture `functions/test/fixtures/alert-filter-cases.json`; change
/// them together.
/// AND across categories, OR within one; an empty category doesn't restrict; invalid filters mean all free food.
nonisolated enum AlertFilterMatcher {
    /// The filters that apply, or nil for all free food (mode "all", none saved, or over the limits).
    static func effective(_ filters: AlertFilters?) -> AlertFilters? {
        guard var filters, filters.mode == .custom else { return nil }
        filters.foods = filters.foods.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard filters.places.count <= AppConfig.alertFilterMaxPlaces,
              filters.places.allSatisfy({ (1...40).contains($0.count) }),
              filters.foods.count <= AppConfig.alertFilterMaxFoods,
              filters.foods.allSatisfy({ (1...AppConfig.alertFilterFoodMaxLength).contains($0.unicodeScalars.count) })
        else { return nil }
        return filters
    }

    static func matches(_ post: FoodPost, filters: AlertFilters?) -> Bool {
        guard let filters = effective(filters) else { return true }
        return matches(post, effective: filters)
    }

    /// `matches` for filters already passed through `effective`, so a list of posts validates them once.
    static func matches(_ post: FoodPost, effective filters: AlertFilters) -> Bool {
        let diets = post.items.isEmpty ? [post.overallDietary] : post.items.map(\.dietary)

        if !filters.diets.isEmpty {
            var allowed: Set<DietaryClass> = []
            if filters.diets.contains(.vegan) { allowed.insert(.vegan) }
            if filters.diets.contains(.vegetarian) { allowed.formUnion([.vegan, .vegetarian]) }
            if filters.diets.contains(.nonVegetarian) { allowed.formUnion([.nonVegetarian, .mixed]) }
            if filters.includeUnknownDiet { allowed.insert(.unknown) }
            guard diets.contains(where: allowed.contains) else { return false }
        }

        if !filters.places.isEmpty, !filters.places.contains(post.buildingId) { return false }

        if filters.avoidAllergens.contains(where: post.allergenWarnings.contains) { return false }
        if filters.skipUnverifiedAllergens, post.allergenWarnings.isEmpty { return false }

        if !filters.foods.isEmpty {
            let texts = [post.title, post.description] + post.items.map(\.name)
            let found = filters.foods.contains { food in texts.contains { keywordMatches(food, in: $0) } }
            if !found { return false }
        }
        return true
    }

    /// Lowercased words with diacritics removed; letters and digits only (same as `words` in filters.ts).
    static func words(_ text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var words: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                current.append(scalar)
            } else if !current.isEmpty {
                words.append(String(current))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty { words.append(String(current)) }
        return words
    }

    /// Whole words in order; a trailing "s" matches either way ("pizza" <-> "pizzas"), "pie" never matches "pierogi".
    static func keywordMatches(_ keyword: String, in text: String) -> Bool {
        let needle = words(keyword)
        guard !needle.isEmpty else { return false }
        let haystack = words(text)
        guard haystack.count >= needle.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            let matched = needle.indices.allSatisfy { offset in
                sameWord(haystack[start + offset], needle[offset])
            }
            if matched { return true }
        }
        return false
    }

    private static func sameWord(_ word: String, _ keyword: String) -> Bool {
        word == keyword || word == keyword + "s" || word + "s" == keyword
    }
}
