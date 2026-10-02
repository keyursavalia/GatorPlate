import SwiftUI

extension Allergen {
    var label: String {
        switch self {
        case .milk: "Milk"
        case .eggs: "Eggs"
        case .fish: "Fish"
        case .shellfish: "Shellfish"
        case .treeNuts: "Tree nuts"
        case .peanuts: "Peanuts"
        case .wheat: "Wheat"
        case .soy: "Soy"
        case .sesame: "Sesame"
        }
    }
}

/// Orange capsule, "May contain" wording because AI allergen detection is never a guarantee.
struct AllergenChip: View {
    let allergen: Allergen

    var body: some View {
        Label(allergen.label, systemImage: "exclamationmark.triangle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.warning)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Color.warning.opacity(0.15), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("May contain \(allergen.label)")
    }
}

#Preview("Chips") {
    HStack {
        AllergenChip(allergen: .soy)
        AllergenChip(allergen: .peanuts)
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
