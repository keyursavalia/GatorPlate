import Foundation

nonisolated enum PostField: Hashable, Sendable {
    case title, description, items, servings, cautions, location, roomDetail, duration, attestation
}

/// Pure validation of the Review form. Blocking issues disable Publish; warnings never do.
nonisolated enum PostValidation {
    struct Issue: Equatable, Sendable {
        let field: PostField
        let message: String
        let isBlocking: Bool
    }

    static func issues(for draft: PostDraft) -> [Issue] {
        var found: [Issue] = []
        func block(_ field: PostField, _ message: String) {
            found.append(Issue(field: field, message: message, isBlocking: true))
        }

        let title = PostText.line(draft.title)
        if title.isEmpty {
            block(.title, "Add a title, like \"FREE: Pizza - SSB 201 - until 8:35 PM\".")
        } else if title.count > AppConfig.maxTitleLength {
            block(.title, "Shorten the title to \(AppConfig.maxTitleLength) characters or fewer.")
        }

        let description = PostText.line(draft.description)
        if description.isEmpty {
            block(.description, "Add a short description of the food.")
        } else if description.count > AppConfig.maxDescriptionLength {
            block(.description, "Shorten the description to \(AppConfig.maxDescriptionLength) characters or fewer.")
        } else if description.count < AppConfig.recommendedDescriptionLength {
            found.append(Issue(
                field: .description,
                message: "Campus posts work best at \(AppConfig.recommendedDescriptionLength) to \(AppConfig.maxDescriptionLength) characters. You can still post.",
                isBlocking: false
            ))
        }

        validateItems(draft, block: block)

        if let servings = draft.servings, !(1...AppConfig.maxServings).contains(servings) {
            block(.servings, "Servings must be between 1 and \(AppConfig.maxServings).")
        }

        let cautions = draft.cautions.map(PostText.line).filter { !$0.isEmpty }
        if cautions.count > AppConfig.maxCautions {
            block(.cautions, "Keep food safety notes to \(AppConfig.maxCautions) or fewer.")
        } else if cautions.contains(where: { $0.count > AppConfig.maxCautionLength }) {
            block(.cautions, "Shorten each food safety note to \(AppConfig.maxCautionLength) characters or fewer.")
        }

        if draft.location == nil {
            if draft.buildingId == nil, let pin = draft.pin, !SFSUCampus.contains(pin) {
                block(.location, "That pin is off campus. Drop it inside the campus map or pick a building.")
            } else {
                block(.location, "Choose the building where the food is.")
            }
        }

        let room = PostText.line(draft.roomDetail)
        if room.isEmpty {
            block(.roomDetail, "Add the room, floor or entrance so people can find it.")
        } else if room.count > AppConfig.maxRoomDetailLength {
            block(.roomDetail, "Shorten the room or floor note to \(AppConfig.maxRoomDetailLength) characters or fewer.")
        }

        if !AppConfig.postDurationOptionsMinutes.contains(draft.durationMinutes)
            || draft.durationMinutes > AppConfig.maxPostDurationMinutes {
            block(.duration, "Pick how long the food will be available.")
        }

        if !draft.attested {
            block(.attestation, "Confirm the food safety statement to post.")
        }
        return found
    }

    private static func validateItems(_ draft: PostDraft, block: (PostField, String) -> Void) {
        let named = draft.cleanedItems
        if named.isEmpty {
            block(.items, "Add at least one food item.")
        } else if named.count > AppConfig.maxFoodItems {
            block(.items, "List at most \(AppConfig.maxFoodItems) items.")
        } else if named.contains(where: { $0.name.count > AppConfig.maxItemNameLength }) {
            block(.items, "Shorten item names to \(AppConfig.maxItemNameLength) characters or fewer.")
        }
    }

    static func blocking(_ issues: [Issue]) -> [Issue] { issues.filter(\.isBlocking) }
}
