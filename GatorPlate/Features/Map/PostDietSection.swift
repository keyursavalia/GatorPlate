import SwiftUI

/// "Diet & allergens" card plus items, cautions and the calorie estimate (hidden by the Settings toggle).
/// AI-derived diets read as an appearance ("Appears vegetarian"); allergens are "May contain", never "free of".
struct PostDietSection: View {
    let post: FoodPost
    let showCalories: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionCard(title: "Diet & allergens", systemImage: "leaf") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    DietaryBadge(dietary: post.overallDietary, isEstimate: post.aiGenerated)
                    if post.allergenWarnings.isEmpty {
                        Label("No allergens listed (unverified)", systemImage: "questionmark.circle")
                            .font(.subheadline)
                    } else {
                        Text("May contain")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityHidden(true)
                        FlowLayout {
                            ForEach(post.allergenWarnings, id: \.self) { AllergenChip(allergen: $0) }
                        }
                    }
                    Text("Confirm allergens and ingredients with the host.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !post.items.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Items").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    ForEach(Array(post.items.enumerated()), id: \.offset) { _, item in
                        Text("\(item.name) · \(post.aiGenerated ? item.dietary.estimateLabel : item.dietary.label)")
                            .font(.subheadline)
                    }
                }
            }

            if !post.cautions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Cautions").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    ForEach(post.cautions, id: \.self) { caution in
                        Label(caution, systemImage: "exclamationmark.shield").font(.subheadline)
                    }
                }
            }

            if showCalories, let calorieLine {
                Label(calorieLine, systemImage: "flame")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Calories (estimate): 420–520 kcal per serving" across items that have an estimate.
    private var calorieLine: String? {
        let ranges = post.items.compactMap(\.calories)
        guard let low = ranges.map(\.low).min(), let high = ranges.map(\.high).max() else { return nil }
        return "Calories (estimate): \(low)–\(high) kcal per serving"
    }
}
