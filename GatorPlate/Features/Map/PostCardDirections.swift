import SwiftUI

/// The Directions area of the bottom card: buttons, loading, the route summary with End route, or a failure message.
/// "Open in Maps" is offered in every state, so food can always be reached.
struct PostCardDirections: View {
    let state: RouteState
    let onDirections: () -> Void
    let onEndRoute: () -> Void
    let onOpenInMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            switch state {
            case .idle:
                buttonRow(directionsTitle: "Directions")
            case .loading:
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView()
                    Text("Finding a walking route...")
                        .font(.subheadline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Finding a walking route")
                openInMapsButton(prominent: false)
            case .routed(let summary):
                routedSummary(summary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.s) { routedButtons }
                    VStack(spacing: Theme.Spacing.s) { routedButtons }
                }
            case .failed(_, let failure):
                Banner(kind: .warning, message: failure.message)
                if failure.canRetry {
                    buttonRow(directionsTitle: "Try again")
                } else {
                    openInMapsButton(prominent: true)
                }
            }
        }
    }

    private func routedSummary(_ summary: RouteSummary) -> some View {
        Label(
            RouteFormatter.summary(distanceMeters: summary.distanceMeters, travelTime: summary.travelTime),
            systemImage: "figure.walk"
        )
        .font(.headline)
        .accessibilityLabel(
            RouteFormatter.spokenSummary(distanceMeters: summary.distanceMeters, travelTime: summary.travelTime)
        )
    }

    @ViewBuilder private var routedButtons: some View {
        Button(action: onEndRoute) {
            Label("End route", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        openInMapsButton(prominent: false)
    }

    private func buttonRow(directionsTitle: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.s) { directionsAndMaps(title: directionsTitle) }
            VStack(spacing: Theme.Spacing.s) { directionsAndMaps(title: directionsTitle) }
        }
    }

    @ViewBuilder private func directionsAndMaps(title: String) -> some View {
        Button(action: onDirections) {
            Label(title, systemImage: "figure.walk")
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Shows a walking route on the map")
        openInMapsButton(prominent: false)
    }

    @ViewBuilder private func openInMapsButton(prominent: Bool) -> some View {
        let button = Button(action: onOpenInMaps) {
            Label("Open in Maps", systemImage: "map")
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .accessibilityHint("Opens Apple Maps with walking directions")
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

#Preview("States") {
    let post = SampleData.mapPosts()[0]
    let summary = RouteSummary(
        postID: post.id,
        coordinates: [],
        distanceMeters: 350,
        travelTime: 270
    )
    return ScrollView {
        VStack(spacing: Theme.Spacing.xl) {
            PostCardDirections(state: .idle, onDirections: {}, onEndRoute: {}, onOpenInMaps: {})
            PostCardDirections(state: .loading(postID: post.id), onDirections: {}, onEndRoute: {}, onOpenInMaps: {})
            PostCardDirections(state: .routed(summary), onDirections: {}, onEndRoute: {}, onOpenInMaps: {})
            PostCardDirections(state: .failed(postID: post.id, .offCampus), onDirections: {}, onEndRoute: {}, onOpenInMaps: {})
            PostCardDirections(state: .failed(postID: post.id, .network), onDirections: {}, onEndRoute: {}, onOpenInMaps: {})
        }
        .padding()
    }
    .environment(\.appEnvironment, .mock)
}
