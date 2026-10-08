import SwiftUI

/// Sheet content for a selected pin. The small detent shows title, time and directions; medium adds the photo,
/// details and poster/report actions.
struct PostBottomCard: View {
    let post: FoodPost
    let viewModel: MapViewModel
    let isExpanded: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if isExpanded, post.hasPhoto {
                    PostPhotoView(postId: post.id, hasPhoto: post.hasPhoto, images: viewModel.images)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                }

                Text(post.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                wrapping {
                    TimeRemainingPill(expiresAt: post.expiresAt)
                    DietaryBadge(dietary: post.overallDietary, isEstimate: post.aiGenerated)
                }

                if isExpanded {
                    details
                }

                PostRouteSection(post: post, viewModel: viewModel)

                if isExpanded {
                    Divider()
                    PostActionsSection(post: post, viewModel: viewModel)
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(post.orgName ?? post.authorName, systemImage: "person.2")
            Label(locationLine, systemImage: "mappin.and.ellipse")
            if let distanceText = viewModel.distanceText(to: post) {
                Label(distanceText, systemImage: "figure.walk")
            }
            if let servings = post.estimatedServings {
                Label("About \(servings) servings", systemImage: "takeoutbag.and.cup.and.straw")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        if !post.description.isEmpty {
            Text(post.description).font(.body)
        }

        allergens

        if let calorieLine {
            Label(calorieLine, systemImage: "flame")
                .font(.subheadline)
        }

        if !post.cautions.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Cautions")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                ForEach(post.cautions, id: \.self) { caution in
                    Label(caution, systemImage: "exclamationmark.shield")
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private var allergens: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if post.allergenWarnings.isEmpty {
                Label("No allergens listed (unverified)", systemImage: "questionmark.circle")
                    .font(.subheadline)
            } else {
                Text("May contain")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                wrapping {
                    ForEach(post.allergenWarnings, id: \.self) { AllergenChip(allergen: $0) }
                }
            }
            Text("Confirm allergens and ingredients with the host.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var locationLine: String {
        [post.locationName, post.locationDetail].compactMap { $0 }.joined(separator: ", ")
    }

    /// "About 420-520 kcal per serving (estimate)" across items that have an estimate.
    private var calorieLine: String? {
        let ranges = post.items.compactMap(\.calories)
        guard let low = ranges.map(\.low).min(), let high = ranges.map(\.high).max() else { return nil }
        return "About \(low)–\(high) kcal per serving (estimate)"
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

#Preview("Medium") {
    PostBottomCard(post: .sample, viewModel: .preview, isExpanded: true)
}

#Preview("Small, AX5") {
    PostBottomCard(post: .sample, viewModel: .preview, isExpanded: false)
        .dynamicTypeSize(.accessibility5)
}
