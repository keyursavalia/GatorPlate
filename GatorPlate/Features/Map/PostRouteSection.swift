import SwiftUI

/// Directions for the selected post: walking route state, ETA and distance, End route, and the Apple Maps
/// fallback, which is always offered.
struct PostRouteSection: View {
    let post: FoodPost
    let viewModel: MapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            switch viewModel.route.state(for: post.id) {
            case .idle:
                wrapping {
                    directionsButton(title: "Directions")
                    openInMapsButton
                }
            case .calculating:
                wrapping {
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                        Text("Finding a walking route...")
                            .font(.subheadline)
                    }
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .accessibilityElement(children: .combine)
                    openInMapsButton
                }
            case .active(_, let route):
                routeSummary(route)
                wrapping {
                    Button(action: viewModel.endRoute) {
                        Label("End route", systemImage: "xmark.circle")
                            .frame(minHeight: Theme.Size.minTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Removes the route from the map")
                    openInMapsButton
                }
            case .failed(_, let failure):
                Label(failure.userMessage, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                wrapping {
                    if failure.isRetryable {
                        directionsButton(title: "Try again")
                    }
                    openInMapsButton
                }
            }
        }
    }

    private func routeSummary(_ route: WalkingRoute) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("\(DistanceText.walk(seconds: route.expectedTravelTime)) · \(DistanceText.distance(meters: route.distanceMeters))",
                  systemImage: "figure.walk")
                .font(.headline)
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityLabel("Walking route: \(DistanceText.walkMinutes(seconds: route.expectedTravelTime)) minutes, \(DistanceText.distance(meters: route.distanceMeters))")
            if viewModel.route.isApproximate {
                Text("Your location is approximate, so the route may start a little off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func directionsButton(title: String) -> some View {
        Button {
            viewModel.requestDirections(to: post)
        } label: {
            Label(title, systemImage: "figure.walk")
                .frame(minHeight: Theme.Size.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Shows a walking route on the campus map")
    }

    private var openInMapsButton: some View {
        Button {
            viewModel.openInAppleMaps(post)
        } label: {
            Label("Open in Apple Maps", systemImage: "map")
                .frame(minHeight: Theme.Size.minTapTarget)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Opens walking directions in Apple Maps")
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
