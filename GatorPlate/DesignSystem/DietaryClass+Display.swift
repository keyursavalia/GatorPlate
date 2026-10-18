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

    var icon: String {
        switch self {
        case .vegan: "leaf.fill"
        case .vegetarian: "carrot.fill"
        case .nonVegetarian: "fork.knife"
        case .mixed: "square.split.2x1.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .vegan, .vegetarian: Theme.Palette.success
        case .nonVegetarian: Theme.Palette.brandPurple
        case .mixed: .teal
        case .unknown: .gray
        }
    }
}
