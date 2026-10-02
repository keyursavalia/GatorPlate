import Foundation

nonisolated enum AccountType: String, Codable, Sendable {
    case student
    case organization
}

nonisolated enum DietaryClass: String, Codable, Sendable {
    case vegan
    case vegetarian
    case nonVegetarian
    case mixed
    case unknown
}

nonisolated enum PostStatus: String, Codable, Sendable {
    case active
    case gone
    case expired
}

nonisolated enum Allergen: String, Codable, CaseIterable, Sendable {
    case milk, eggs, fish, shellfish, treeNuts, peanuts, wheat, soy, sesame
}
