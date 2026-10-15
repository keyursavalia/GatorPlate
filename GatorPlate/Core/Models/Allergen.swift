import Foundation

/// The nine major allergens surfaced as "May contain" chips.
nonisolated enum Allergen: String, Codable, CaseIterable, Sendable {
    case milk, eggs, fish, shellfish, treeNuts, peanuts, wheat, soy, sesame
}

nonisolated extension Allergen {
    var displayName: String {
        switch self {
        case .milk: "Milk"
        case .eggs: "Eggs"
        case .fish: "Fish"
        case .shellfish: "Shellfish"
        case .treeNuts: "Tree nuts"
        case .peanuts: "Peanuts"
        case .wheat: "Wheat"
        case .soy: "Soy"
        case .sesame: "Sesame"
        }
    }
}
