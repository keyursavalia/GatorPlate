import MapKit
import SwiftUI

/// The campus-locked map: pan, zoom and rotate inside SFSU, user location, mock pins, and a bottom card.
struct CampusMapView: View {
    @State private var viewModel: MapViewModel
    @Namespace private var mapScope
    @Environment(\.openURL) private var openURL

    private static let smallDetent = PresentationDetent.height(280)

    init(location: any LocationProviding, posts: [FoodPost] = SampleData.mapPosts()) {
        _viewModel = State(initialValue: MapViewModel(location: location, posts: posts))
    }

    var body: some View {
        Map(
            position: $viewModel.cameraPosition,
            bounds: SFSUCampus.cameraBounds,
            interactionModes: [.pan, .zoom, .rotate],
            selection: $viewModel.selectedPostID,
            scope: mapScope
        ) {
            UserAnnotation()

            ForEach(viewModel.activePosts) { post in
                Annotation(
                    post.title,
                    coordinate: CLLocationCoordinate2D(latitude: post.latitude, longitude: post.longitude),
                    anchor: .center
                ) {
                    MapPin(dietary: post.overallDietary, isSelected: viewModel.selectedPostID == post.id)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.accessibilityLabel(for: post))
                        .accessibilityAddTraits(.isButton)
                }
                .tag(post.id)
            }
        }
        .mapStyle(
            .standard(
                elevation: .flat,
                pointsOfInterest: .including([.cafe, .restaurant, .bakery, .foodMarket, .library, .university, .fitnessCenter, .park])
            )
        )
        .mapControlVisibility(.hidden)
        .accessibilityHint("Pins show free food on campus. The Feed tab lists the same posts.")
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                banner
                controls
            }
        }
        .mapScope(mapScope)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.selectedPostID)
        .sheet(isPresented: sheetBinding) {
            if let post = viewModel.selectedPost {
                PostBottomCard(post: post, distanceText: viewModel.distanceText(to: post))
                    .presentationDetents([Self.smallDetent, .medium])
                    .presentationBackgroundInteraction(.enabled(upThrough: Self.smallDetent))
                    .presentationDragIndicator(.visible)
            }
        }
        .task { await viewModel.run() }
    }

    // MARK: Pieces

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedPost != nil },
            set: { isPresented in
                if !isPresented { viewModel.selectedPostID = nil }
            }
        )
    }

    private var controls: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button(action: viewModel.recenter) {
                Image(systemName: "location.fill")
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Recenter map")
            .accessibilityHint("Moves the map to your location, or to the campus if you are away from it.")

            MapCompass(scope: mapScope)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder private var banner: some View {
        switch viewModel.banner {
        case .permissionPrompt:
            Banner(
                kind: .info,
                message: "Allow location to see where you are on campus. We only use it while the map is open.",
                actionTitle: "Allow location",
                action: viewModel.requestPermission
            )
            .padding(Theme.Spacing.l)
        case .locationDenied:
            Banner(
                kind: .warning,
                message: "Location is off, so your dot is hidden. The campus map still works.",
                actionTitle: "Open Settings",
                action: openSettings
            )
            .padding(Theme.Spacing.l)
        case .reducedAccuracy:
            Banner(
                kind: .warning,
                message: "Precise location is off, directions may be less accurate.",
                actionTitle: "Use precise location",
                action: viewModel.requestFullAccuracy
            )
            .padding(Theme.Spacing.l)
        case .offCampus:
            Banner(kind: .info, message: "You're off campus. The map stays on SFSU.")
                .padding(Theme.Spacing.l)
        case nil:
            EmptyView()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

#Preview("On campus") {
    CampusMapView(location: MockLocationProvider())
        .environment(\.appEnvironment, .mock)
}

#Preview("Permission needed") {
    CampusMapView(location: MockLocationProvider(status: .notDetermined, coordinate: nil))
        .environment(\.appEnvironment, .mock)
}

#Preview("Off campus") {
    CampusMapView(
        location: MockLocationProvider(coordinate: Coordinate(latitude: 37.3349, longitude: -122.0090))
    )
    .environment(\.appEnvironment, .mock)
}
