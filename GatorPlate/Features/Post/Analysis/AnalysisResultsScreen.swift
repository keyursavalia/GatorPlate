import SwiftUI

/// Temporary read-only view of the sanitized AI draft. Sprint 05 replaces it with the editable Review form.
struct AnalysisResultsScreen: View {
    let photo: CapturedPhoto
    let result: FoodAnalysisResult
    var evalLine: String?
    let onRetake: () -> Void

    @State private var isShowingContinueInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Image(uiImage: photo.previewImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .accessibilityLabel("Your food photo")

                section("Title") {
                    Text(result.title).font(.title3.bold())
                }
                section("Description") {
                    Text(result.description).font(.body)
                }
                section("Items") { items }
                section("Allergens") { allergens }
                if !result.cautions.isEmpty {
                    section("Cautions") { cautions }
                }
                if let servings = result.estimatedServings {
                    section("Servings") {
                        Text("About \(servings) servings")
                    }
                }

                VStack(spacing: Theme.Spacing.md) {
                    PrimaryButton(title: "Continue") { isShowingContinueInfo = true }
                    Button(action: onRetake) {
                        Text("Retake photo")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.Palette.brandPurple)
                    #if DEBUG
                    if let evalLine {
                        ShareLink("Share eval line", item: evalLine)
                            .font(.footnote)
                    }
                    #endif
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .alert("Editing arrives next", isPresented: $isShowingContinueInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Soon you'll review and edit this draft, pick a location and publish.")
        }
    }

    // MARK: Sections

    private var items: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if result.items.isEmpty {
                Text("No items identified.").foregroundStyle(.secondary)
            }
            ForEach(result.items, id: \.self) { item in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.name).font(.body.weight(.semibold))
                    wrapping {
                        DietaryBadge(dietary: item.dietary, isEstimate: true)
                        if let calories = item.calories {
                            Label("\(calories.low)–\(calories.high) cal · estimate", systemImage: "flame")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("\(calories.low) to \(calories.high) calories per serving, estimate")
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Divider()
            HStack(spacing: Theme.Spacing.sm) {
                Text("Overall").font(.subheadline.weight(.semibold))
                DietaryBadge(dietary: result.overallDietary, isEstimate: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var allergens: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if result.allergensUnverified {
                Banner(style: .warning, message: "Allergen info unverified, ask the host.")
            } else {
                Text("May contain")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                wrapping {
                    ForEach(result.allergens, id: \.self) { AllergenChip(allergen: $0) }
                }
            }
            Text("Always confirm with the host.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var cautions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(result.cautions, id: \.self) { caution in
                Label(caution, systemImage: "exclamationmark.shield")
                    .font(.subheadline)
            }
        }
    }

    // MARK: Helpers

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                AIBadge()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Horizontal when it fits, stacked at large Dynamic Type sizes.
    private func wrapping(@ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) { content }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) { content }
        }
    }
}
