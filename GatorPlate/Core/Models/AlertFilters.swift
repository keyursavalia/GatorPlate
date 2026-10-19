import Foundation

/// "What to alert me about", at `users/{uid}.alertFilters`. Chosen by the student for themselves, owner-only,
/// never shown to others, never logged, never used for ranking; deleted with the account. The `onPostCreated`
/// function (`functions/src/filters.ts`) applies them; `AlertFilterMatcher` mirrors that logic for the live preview.
nonisolated struct AlertFilters: Codable, Equatable, Sendable {
    enum Mode: String, Codable, Sendable {
        /// All free food. Selections are kept but ignored.
        case all
        case custom
    }

    enum Diet: String, Codable, CaseIterable, Sendable {
        case vegan, vegetarian, nonVegetarian

        var displayName: String {
            switch self {
            case .vegan: "Vegan"
            case .vegetarian: "Vegetarian"
            case .nonVegetarian: "Non-vegetarian"
            }
        }
    }

    var mode = Mode.all
    /// Empty = any diet. `vegetarian` also allows vegan items; `nonVegetarian` also allows mixed posts.
    var diets: [Diet] = []
    var includeUnknownDiet = false
    /// Catalog building IDs; empty = anywhere on campus.
    var places: [String] = []
    var avoidAllergens: [Allergen] = []
    /// Skip posts with no allergen info.
    var skipUnverifiedAllergens = false
    /// Keywords such as "pizza" or "red bull".
    var foods: [String] = []
    var updatedAt: Date?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case mode, diets, includeUnknownDiet, places, avoidAllergens, skipUnverifiedAllergens, foods, updatedAt
    }

    /// Never throws: a malformed value reads as "all free food" (like the function), so a bad field can never
    /// block loading the profile.
    init(from decoder: any Decoder) throws {
        self.init()
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mode = try container.decode(Mode.self, forKey: .mode)
            diets = try container.decodeIfPresent([Diet].self, forKey: .diets) ?? []
            includeUnknownDiet = try container.decodeIfPresent(Bool.self, forKey: .includeUnknownDiet) ?? false
            places = try container.decodeIfPresent([String].self, forKey: .places) ?? []
            avoidAllergens = try container.decodeIfPresent([Allergen].self, forKey: .avoidAllergens) ?? []
            skipUnverifiedAllergens = try container.decodeIfPresent(Bool.self, forKey: .skipUnverifiedAllergens) ?? false
            foods = try container.decodeIfPresent([String].self, forKey: .foods) ?? []
            updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
        } catch {
            self = AlertFilters()
        }
    }
}
