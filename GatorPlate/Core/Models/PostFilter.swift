import Foundation

/// What the student wants to see on the Map and in the Feed (one filter for both tabs). Diet, places, allergens and
/// favorite foods mean exactly what they mean in Custom notifications (`AlertFilters`); time left and walking
/// distance are browse-only. Kept on this phone only (`PostFilterStore`): never written to Firestore, never logged,
/// never sent to the Cloud Function, removed when the account is deleted.
nonisolated struct PostFilter: Codable, Equatable, Sendable {
    /// Empty = any diet. `vegetarian` also allows vegan items; `nonVegetarian` also allows mixed posts.
    var diets: [AlertFilters.Diet] = []
    var includeUnknownDiet = false
    /// Catalog building IDs; empty = anywhere on campus.
    var places: [String] = []
    var avoidAllergens: [Allergen] = []
    /// Hide posts with no allergen info.
    var skipUnverifiedAllergens = false
    var foods: [String] = []
    /// Only posts with at least this many minutes left (`AppConfig.browseFilterMinutesLeftOptions`).
    var minMinutesLeft: Int?
    /// Only posts within this many minutes' walk (`AppConfig.browseFilterWalkMinutesOptions`). Ignored without a
    /// location, so it can never hide every post.
    var maxWalkMinutes: Int?

    init() {}

    /// A filter category in use, for the badge count and the Feed chips.
    enum Category: CaseIterable, Sendable {
        case diet, places, foods, allergens, timeLeft, distance
    }

    var categories: [Category] {
        Category.allCases.filter { category in
            switch category {
            case .diet: !diets.isEmpty
            case .places: !places.isEmpty
            case .foods: !foods.isEmpty
            case .allergens: !avoidAllergens.isEmpty || skipUnverifiedAllergens
            case .timeLeft: minMinutesLeft != nil
            case .distance: maxWalkMinutes != nil
            }
        }
    }

    /// Categories in use (the filter button's badge).
    var activeCount: Int { categories.count }

    var isEmpty: Bool { activeCount == 0 }

    /// The diet, place, allergen and food picks in the notification-filter vocabulary, so `AlertFilterMatcher`
    /// stays the only copy of that logic and the shared pick sections edit both.
    var picks: AlertFilters {
        get {
            var filters = AlertFilters()
            filters.mode = .custom
            filters.diets = diets
            filters.includeUnknownDiet = includeUnknownDiet
            filters.places = places
            filters.avoidAllergens = avoidAllergens
            filters.skipUnverifiedAllergens = skipUnverifiedAllergens
            filters.foods = foods
            return filters
        }
        set {
            diets = newValue.diets
            includeUnknownDiet = !newValue.diets.isEmpty && newValue.includeUnknownDiet
            places = newValue.places
            avoidAllergens = newValue.avoidAllergens
            skipUnverifiedAllergens = newValue.skipUnverifiedAllergens
            foods = newValue.foods
        }
    }

    /// "Use my notification filters": a one-way copy of the picks. Time left and distance stay as they are.
    mutating func copyPicks(from alerts: AlertFilters) {
        picks = alerts
    }

    private enum CodingKeys: String, CodingKey {
        case diets, includeUnknownDiet, places, avoidAllergens, skipUnverifiedAllergens, foods
        case minMinutesLeft, maxWalkMinutes
    }

    /// Never throws: malformed saved data reads as no filter, and an option this version doesn't offer is dropped.
    init(from decoder: any Decoder) throws {
        self.init()
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            diets = try container.decodeIfPresent([AlertFilters.Diet].self, forKey: .diets) ?? []
            includeUnknownDiet = try container.decodeIfPresent(Bool.self, forKey: .includeUnknownDiet) ?? false
            places = try container.decodeIfPresent([String].self, forKey: .places) ?? []
            avoidAllergens = try container.decodeIfPresent([Allergen].self, forKey: .avoidAllergens) ?? []
            skipUnverifiedAllergens = try container.decodeIfPresent(Bool.self, forKey: .skipUnverifiedAllergens) ?? false
            foods = try container.decodeIfPresent([String].self, forKey: .foods) ?? []
            minMinutesLeft = try container.decodeIfPresent(Int.self, forKey: .minMinutesLeft)
                .flatMap { AppConfig.browseFilterMinutesLeftOptions.contains($0) ? $0 : nil }
            maxWalkMinutes = try container.decodeIfPresent(Int.self, forKey: .maxWalkMinutes)
                .flatMap { AppConfig.browseFilterWalkMinutesOptions.contains($0) ? $0 : nil }
        } catch {
            self = PostFilter()
        }
    }
}
