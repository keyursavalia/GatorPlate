import Foundation

/// A validated, cleaned post ready to publish. Built by `PostDraftValidator.submission`.
/// Holds only user-approved fields: nothing from the raw AI response.
nonisolated struct PostSubmission: Equatable, Sendable {
    /// Created once per draft so a retried publish writes the same document.
    var postId: String
    var author: PostAuthor
    var title: String
    var description: String
    var items: [FoodItem]
    var overallDietary: DietaryClass
    var allergens: [Allergen]
    var cautions: [String]
    var estimatedServings: Int?
    var location: PostLocation
    var locationDetail: String
    var durationMinutes: Int
    var aiGenerated: Bool
    var editedAfterAI: Bool
}
