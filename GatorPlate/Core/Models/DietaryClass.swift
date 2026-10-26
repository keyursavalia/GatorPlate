import Foundation

nonisolated enum DietaryClass: String, Codable, Sendable {
    case vegan, vegetarian, nonVegetarian, mixed, unknown
}
