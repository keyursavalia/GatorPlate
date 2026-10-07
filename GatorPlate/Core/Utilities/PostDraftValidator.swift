import Foundation

/// Validation rules for the Review form (mirrored by `firestore.rules`). Pure; no I/O.
nonisolated enum PostDraftValidator {
    enum Field: Hashable, Sendable {
        case title, description, items, cautions, servings, location, locationDetail, duration, attestation
    }

    struct Issue: Hashable, Sendable {
        let field: Field
        let message: String
        /// Blocking issues disable Publish; the rest are warnings.
        let isBlocking: Bool
    }

    static func issues(for draft: PostDraft) -> [Issue] {
        var issues: [Issue] = []
        func block(_ field: Field, _ message: String) { issues.append(Issue(field: field, message: message, isBlocking: true)) }
        func warn(_ field: Field, _ message: String) { issues.append(Issue(field: field, message: message, isBlocking: false)) }

        let title = PostText.clean(draft.title)
        if title.isEmpty {
            block(.title, "Add a title.")
        } else if title.count > AppConfig.postTitleMaxLength {
            block(.title, "Keep the title under \(AppConfig.postTitleMaxLength) characters.")
        } else if !title.lowercased().hasPrefix("free") {
            warn(.title, "Titles that start with \"FREE\" get noticed faster.")
        }

        let description = PostText.clean(draft.description)
        if description.isEmpty {
            block(.description, "Add a short description.")
        } else if description.count > AppConfig.postDescriptionMaxLength {
            block(.description, "Keep the description under \(AppConfig.postDescriptionMaxLength) characters.")
        } else if description.count < AppConfig.postDescriptionTargetMinLength {
            warn(.description, "Aim for \(AppConfig.postDescriptionTargetMinLength)-\(AppConfig.postDescriptionMaxLength) characters: what it is, how much, anything to know.")
        }

        let items = draft.filledItems
        if items.isEmpty {
            block(.items, "Add at least one food item.")
        } else if items.count > AppConfig.postMaxItems {
            block(.items, "Up to \(AppConfig.postMaxItems) items.")
        } else if items.contains(where: { $0.name.count > AppConfig.postItemNameMaxLength }) {
            block(.items, "Keep item names under \(AppConfig.postItemNameMaxLength) characters.")
        }

        let cautions = draft.filledCautions
        if cautions.count > AppConfig.postMaxCautions {
            block(.cautions, "Up to \(AppConfig.postMaxCautions) notes.")
        } else if cautions.contains(where: { $0.count > AppConfig.postCautionMaxLength }) {
            block(.cautions, "Keep each note under \(AppConfig.postCautionMaxLength) characters.")
        }

        if let servings = draft.estimatedServings, !AppConfig.postServingsRange.contains(servings) {
            block(.servings, "Servings must be \(AppConfig.postServingsRange.lowerBound)-\(AppConfig.postServingsRange.upperBound).")
        }

        switch draft.location {
        case nil:
            block(.location, "Pick where the food is.")
        case .pin(let coordinate, _) where !SFSUCampus.isValidPinLocation(coordinate):
            block(.location, "The pin must be on the SFSU campus.")
        default:
            break
        }

        let detail = PostText.clean(draft.locationDetail)
        if detail.isEmpty {
            block(.locationDetail, "Add the room, floor or entrance.")
        } else if detail.count > AppConfig.postLocationDetailMaxLength {
            block(.locationDetail, "Keep it under \(AppConfig.postLocationDetailMaxLength) characters.")
        }

        if !AppConfig.postDurationOptionsMinutes.contains(draft.durationMinutes) {
            block(.duration, "Pick how long the food is available.")
        }

        if !draft.safetyAttested {
            block(.attestation, "Confirm the food has been kept safe.")
        }
        return issues
    }

    /// Nil while any blocking issue remains.
    static func submission(from draft: PostDraft, postId: String, author: PostAuthor,
                           aiGenerated: Bool, editedAfterAI: Bool) -> PostSubmission? {
        guard !issues(for: draft).contains(where: \.isBlocking), let location = draft.location else { return nil }
        return PostSubmission(
            postId: postId, author: author,
            title: PostText.clean(draft.title),
            description: PostText.clean(draft.description),
            items: draft.filledItems,
            overallDietary: draft.overallDietary,
            allergens: draft.orderedAllergens,
            cautions: draft.filledCautions,
            estimatedServings: draft.estimatedServings,
            location: location,
            locationDetail: PostText.clean(draft.locationDetail),
            durationMinutes: draft.durationMinutes,
            aiGenerated: aiGenerated,
            editedAfterAI: editedAfterAI)
    }
}
