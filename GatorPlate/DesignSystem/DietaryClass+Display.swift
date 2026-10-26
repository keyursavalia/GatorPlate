import SwiftUI

extension DietaryClass {
    var label: String {
        switch self {
        case .vegan: "Vegan"
        case .vegetarian: "Vegetarian"
        case .nonVegetarian: "Non-veg"
        case .mixed: "Mixed"
        case .unknown: "Diet unknown"
        }
    }

    /// AI-derived values in detail views read as an appearance, not a fact ("Appears vegan").
    var estimateLabel: String {
        switch self {
        case .vegan: "Appears vegan"
        case .vegetarian: "Appears vegetarian"
        case .nonVegetarian: "Appears to contain meat or fish"
        case .mixed: "Mixed: veg and non-veg"
        case .unknown: "Diet unknown"
        }
    }

    /// Vegan keeps the leaf; vegetarian and non-veg use the familiar food-label mark (a dot in a square),
    /// green and red. Always shown next to `label`, so the color is never the only signal.
    var icon: String {
        switch self {
        case .vegan: "leaf.fill"
        case .vegetarian: "dot.square"
        case .nonVegetarian: "dot.square"
        case .mixed: "square.split.2x1.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .vegan, .vegetarian: Theme.Palette.success
        case .nonVegetarian: Theme.Palette.danger
        case .mixed: .teal
        case .unknown: .gray
        }
    }
}
