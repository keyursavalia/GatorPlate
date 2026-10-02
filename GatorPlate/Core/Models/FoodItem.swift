import Foundation

/// Calories per typical serving. An estimate, never a guarantee.
nonisolated struct CalorieRange: Codable, Hashable, Sendable {
    var low: Int
    var high: Int
}

nonisolated struct FoodItem: Codable, Hashable, Sendable {
    var name: String
    var dietary: DietaryClass
    var calories: CalorieRange?
}
