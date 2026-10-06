import Foundation

/// The nine major allergens surfaced as "May contain" chips.
nonisolated enum Allergen: String, Codable, CaseIterable, Sendable {
    case milk, eggs, fish, shellfish, treeNuts, peanuts, wheat, soy, sesame
}
