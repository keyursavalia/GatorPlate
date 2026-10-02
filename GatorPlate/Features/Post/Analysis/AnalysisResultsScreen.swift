import SwiftUI

/// Read-only preview of the AI draft. Editing arrives with the Review screen in Sprint 5.
struct AnalysisResultsScreen: View {
    let photo: CapturedPhoto
    let result: FoodAnalysisResult
    let onRetake: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Image(uiImage: photo.previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
                        .accessibilityLabel("Your photo")

                    AIBadge()

                    Text(result.title)
                        .font(.title2.bold())
                    Text(result.description)
                        .font(.body)

                    section("Items") {
                        ForEach(Array(result.items.enumerated()), id: \.offset) { _, item in
                            itemRow(item)
                        }
                        Text(overallLabel(result.overallDietary))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    section("Allergens") { allergens }

                    if let servings = result.estimatedServings {
                        Label("About \(servings) servings", systemImage: "person.2")
                            .font(.subheadline)
                    }

                    if !result.cautions.isEmpty {
                        section("Food safety") {
                            ForEach(result.cautions, id: \.self) { caution in
                                Label(caution, systemImage: "thermometer.medium")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }

            VStack(spacing: Theme.Spacing.s) {
                PrimaryButton(title: "Done", action: onDone)
                Button("Retake", action: onRetake)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color.surface.ignoresSafeArea())
    }

    // MARK: Pieces

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func itemRow(_ item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.body.weight(.medium))
                Spacer(minLength: Theme.Spacing.s)
                DietaryBadge(dietary: item.dietary)
            }
            if let calories = item.calories {
                Text("About \(calories.low) to \(calories.high) cal per serving (estimate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var allergens: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if result.allergensUnverified {
                Text("Allergen info unverified, ask the host.")
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("May contain")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                FlowLayoutLite(spacing: Theme.Spacing.s) {
                    ForEach(result.allergenWarnings, id: \.self) { AllergenChip(allergen: $0) }
                }
            }
            Text("Always confirm with the host.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Detail-view wording: AI-derived dietary info only "appears" to be true.
    private func overallLabel(_ dietary: DietaryClass) -> String {
        switch dietary {
        case .vegan: "Appears vegan"
        case .vegetarian: "Appears vegetarian"
        case .nonVegetarian: "Appears non-vegetarian"
        case .mixed: "Mixed: some items are non-vegetarian"
        case .unknown: "Dietary info unknown"
        }
    }
}

/// Minimal wrapping layout for chips.
private struct FlowLayoutLite: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(in: bounds.width, subviews: subviews)
        for (subview, origin) in zip(subviews, layout.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

#Preview("Results") {
    AnalysisResultsScreen(
        photo: PreviewSupport.photo(variant: 1), result: SampleData.analysisCautious, onRetake: {}, onDone: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Results, no allergens") {
    AnalysisResultsScreen(
        photo: PreviewSupport.photo(variant: 2), result: SampleData.analysisNoAllergens, onRetake: {}, onDone: {}
    )
    .environment(\.appEnvironment, .mock)
}
