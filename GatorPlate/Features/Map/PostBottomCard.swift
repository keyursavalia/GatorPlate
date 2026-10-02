import SwiftUI

/// Sheet content for a selected pin. Small detent: title, time, directions. Medium: everything.
/// Directions are disabled until Sprint 6.
struct PostBottomCard: View {
    let post: FoodPost
    var distanceText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(post.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                header

                directionsButtons

                Divider()

                details
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(post.orgName ?? post.authorName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.s) { pills }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) { pills }
            }
        }
    }

    @ViewBuilder private var pills: some View {
        TimeRemainingPill(expiresAt: post.expiresAt)
        DietaryBadge(dietary: post.overallDietary)
    }

    private var directionsButtons: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.s) { buttons }
                VStack(spacing: Theme.Spacing.s) { buttons }
            }
            Text("Directions arrive in a later update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var buttons: some View {
        Button {} label: {
            Label("Directions", systemImage: "figure.walk")
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(true)

        Button {} label: {
            Label("Open in Maps", systemImage: "map")
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.bordered)
        .disabled(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if !post.allergenWarnings.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("May contain")
                        .font(.subheadline.weight(.semibold))
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.s) { chips }
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) { chips }
                    }
                }
            }

            if let calories = calorieText {
                Text(calories)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label(locationText, systemImage: "mappin.and.ellipse")
                .font(.subheadline)

            Text(post.description)
                .font(.body)

            Text("Double-check allergens with the host.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(post.allergenWarnings, id: \.self) { allergen in
            AllergenChip(allergen: allergen)
        }
    }

    private var locationText: String {
        var parts = [post.locationName]
        if let detail = post.locationDetail { parts.append(detail) }
        if let distanceText { parts.append(distanceText) }
        return parts.joined(separator: ", ")
    }

    private var calorieText: String? {
        let ranges = post.items.compactMap(\.calories)
        guard !ranges.isEmpty else { return nil }
        let low = ranges.reduce(0) { $0 + $1.low }
        let high = ranges.reduce(0) { $0 + $1.high }
        return "~\(low)-\(high) kcal per serving (estimate)"
    }
}

#Preview("Card") {
    PostBottomCard(post: SampleData.mapPosts()[0], distanceText: "120 m")
        .environment(\.appEnvironment, .mock)
}

#Preview("Card, large text") {
    PostBottomCard(post: SampleData.mapPosts()[0], distanceText: "120 m")
        .dynamicTypeSize(.accessibility3)
        .environment(\.appEnvironment, .mock)
}
