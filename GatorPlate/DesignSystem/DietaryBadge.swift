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

/// Icon + label for a post's overall diet.
struct DietaryBadge: View {
    let dietary: DietaryClass

    var body: some View {
        Label(dietary.label, systemImage: dietary.icon)
            .font(.subheadline.weight(.semibold))
            .labelStyle(BadgeLabelStyle(tint: dietary.tint))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(dietary.tint.opacity(0.15), in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Diet: \(dietary.label)")
    }
}

/// Tinted icon, primary-colored text so contrast stays readable.
private struct BadgeLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            configuration.icon.foregroundStyle(tint)
            configuration.title.foregroundStyle(.primary)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        DietaryBadge(dietary: .vegan)
        DietaryBadge(dietary: .vegetarian)
        DietaryBadge(dietary: .nonVegetarian)
        DietaryBadge(dietary: .mixed)
        DietaryBadge(dietary: .unknown)
    }
}
