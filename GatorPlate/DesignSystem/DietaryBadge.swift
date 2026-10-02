import SwiftUI

extension DietaryClass {
    var label: String {
        switch self {
        case .vegan: "Vegan"
        case .vegetarian: "Vegetarian"
        case .nonVegetarian: "Non-veg"
        case .mixed: "Mixed"
        case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .vegan, .vegetarian: "leaf"
        case .nonVegetarian, .mixed: "fork.knife"
        case .unknown: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .vegan, .vegetarian: .success
        case .nonVegetarian, .mixed: .brandPurple
        case .unknown: .secondary
        }
    }
}

/// Icon + label for the dietary class.
struct DietaryBadge: View {
    let dietary: DietaryClass

    var body: some View {
        Label(dietary.label, systemImage: dietary.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(dietary.tint)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(dietary.tint.opacity(0.15), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Dietary: \(dietary.label)")
    }
}

#Preview("All classes") {
    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
        DietaryBadge(dietary: .vegan)
        DietaryBadge(dietary: .vegetarian)
        DietaryBadge(dietary: .nonVegetarian)
        DietaryBadge(dietary: .mixed)
        DietaryBadge(dietary: .unknown)
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
