import Foundation

nonisolated struct FoodItem: Codable, Hashable, Sendable {
    var name: String
    var dietary: DietaryClass
    var calories: CalorieRange?
}
