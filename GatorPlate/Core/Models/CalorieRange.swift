import Foundation

/// Estimated calories per typical serving.
nonisolated struct CalorieRange: Codable, Hashable, Sendable {
    var low: Int
    var high: Int
}
