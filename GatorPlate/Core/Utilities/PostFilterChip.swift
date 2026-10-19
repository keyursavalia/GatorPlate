import Foundation

/// One removable pick in the Feed's active-filter row ("Vegetarian ✕", "Library ✕", "10+ min ✕").
nonisolated enum PostFilterChip: Hashable, Sendable {
    case diet(AlertFilters.Diet)
    case place(String)
    case food(String)
    case allergen(Allergen)
    case skipUnverified
    case timeLeft(Int)
    case distance(Int)

    /// Every pick in `filter`, in the filter sheet's order.
    static func chips(for filter: PostFilter) -> [PostFilterChip] {
        filter.diets.map(PostFilterChip.diet)
            + filter.places.map(PostFilterChip.place)
            + filter.foods.map(PostFilterChip.food)
            + filter.avoidAllergens.map(PostFilterChip.allergen)
            + (filter.skipUnverifiedAllergens ? [.skipUnverified] : [])
            + (filter.minMinutesLeft.map { [.timeLeft($0)] } ?? [])
            + (filter.maxWalkMinutes.map { [.distance($0)] } ?? [])
    }

    var title: String {
        switch self {
        case .diet(let diet): diet.displayName
        case .place(let id): CampusBuilding.byId(id)?.shortName ?? id
        case .food(let food): food
        case .allergen(let allergen): "No \(allergen.displayName.lowercased())"
        case .skipUnverified: "Allergens listed"
        case .timeLeft(let minutes): "\(minutes)+ min left"
        case .distance(let minutes): "\(minutes) min walk"
        }
    }

    /// "Remove Vegetarian filter".
    var accessibilityLabel: String {
        "Remove \(title) filter"
    }

    func removed(from filter: PostFilter) -> PostFilter {
        var filter = filter
        var picks = filter.picks
        switch self {
        case .diet(let diet): picks.diets.removeAll { $0 == diet }
        case .place(let id): picks.removePlace(id)
        case .food(let food): picks.removeFood(food)
        case .allergen(let allergen): picks.avoidAllergens.removeAll { $0 == allergen }
        case .skipUnverified: picks.skipUnverifiedAllergens = false
        case .timeLeft: filter.minMinutesLeft = nil
        case .distance: filter.maxWalkMinutes = nil
        }
        filter.picks = picks
        return filter
    }
}
