import SwiftUI

extension Allergen {
    var displayName: String {
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

/// Orange capsule with a warning icon. Read as "May contain <allergen>".
struct AllergenChip: View {
    let allergen: Allergen

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.Palette.warning)
            Text(allergen.displayName).foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Palette.warning.opacity(0.15), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("May contain \(allergen.displayName)")
    }
}

#Preview {
    HStack {
        AllergenChip(allergen: .soy)
        AllergenChip(allergen: .peanuts)
    }
}
