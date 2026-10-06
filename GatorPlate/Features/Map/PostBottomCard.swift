import SwiftUI

/// Sheet content for a selected pin. The small detent shows title, time and Directions; medium adds details.
struct PostBottomCard: View {
    let post: FoodPost
    let distanceText: String?
    let isExpanded: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(post.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                wrapping {
                    TimeRemainingPill(expiresAt: post.expiresAt)
                    DietaryBadge(dietary: post.overallDietary)
                }

                if isExpanded {
                    details
                }

                directionsButtons
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
            if let distanceText {
                Label(distanceText, systemImage: "figure.walk")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        if !post.description.isEmpty {
            Text(post.description).font(.body)
        }

        if !post.allergenWarnings.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("May contain")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                wrapping {
                    ForEach(post.allergenWarnings, id: \.self) { AllergenChip(allergen: $0) }
                }
            }
        }

        if let calorieLine {
            Label(calorieLine, systemImage: "flame")
                .font(.subheadline)
        }
    }

    private var directionsButtons: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            wrapping {
                Button {} label: {
                    Label("Directions", systemImage: "figure.walk")
                        .frame(minHeight: Theme.Size.minTapTarget)
                }
                .buttonStyle(.borderedProminent)

                if isExpanded {
                    Button {} label: {
                        Label("Open in Maps", systemImage: "map")
                            .frame(minHeight: Theme.Size.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .disabled(true)
            .accessibilityHint("Available soon")

            Text("Walking directions are coming soon.")
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
    PostBottomCard(post: .sample, distanceText: "350 ft away", isExpanded: true)
}

#Preview("Small, AX5") {
    PostBottomCard(post: .sample, distanceText: nil, isExpanded: false)
        .dynamicTypeSize(.accessibility5)
}
