import Foundation

/// Wire names used by the Gemini response schema (snake_case, per `docs/04-AI-GEMINI-SPEC.md`).
extension Allergen {
    nonisolated var schemaValue: String {
        switch self {
        case .treeNuts: "tree_nuts"
        default: rawValue
        }
    }

    nonisolated init?(schemaValue: String) {
        let normalized = schemaValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = Allergen.allCases.first(where: { $0.schemaValue == normalized }) else { return nil }
        self = match
    }
}

extension DietaryClass {
    /// Per-item values the model may return. `mixed` is never accepted from the model.
    nonisolated static let itemSchemaValues = ["vegan", "vegetarian", "non_vegetarian", "unknown"]

    /// Anything unrecognized becomes `.unknown`, never a guess.
    nonisolated init(itemSchemaValue: String?) {
        switch itemSchemaValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "vegan": self = .vegan
        case "vegetarian": self = .vegetarian
        case "non_vegetarian": self = .nonVegetarian
        default: self = .unknown
        }
    }
}
