import MapKit
import SwiftUI

/// The campus-locked map: pan, zoom and rotate inside SFSU, user location, live pins, the walking route, and a bottom card.
struct CampusMapView: View {
    let viewModel: MapViewModel

    @Namespace private var mapScope
    @Environment(\.openURL) private var openURL

    private static let smallDetent = PresentationDetent.height(280)

    var body: some View {
        @Bindable var viewModel = viewModel
        return Map(
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
                    // Its own timeline keeps the spoken minutes current without re-running the whole ForEach.
                    TimelineView(.periodic(from: .now, by: TimeInterval(AppConfig.timeRemainingRefreshSeconds))) { context in
                        MapPin(dietary: post.overallDietary, isSelected: viewModel.selectedPostID == post.id)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(viewModel.accessibilityLabel(for: post, now: context.date))
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .tag(post.id)
            }

            if let route = viewModel.visibleRoute {
                MapPolyline(coordinates: route.coordinates.map(\.clCoordinate))
                    .stroke(
                        Color.brandPurple,
                        style: StrokeStyle(lineWidth: AppConfig.routeLineWidth, lineCap: .round, lineJoin: .round)
                    )
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
        .animation(.default, value: viewModel.activePosts.map(\.id))
        .onChange(of: viewModel.route.state) { viewModel.fitCameraToRoute() }
        .sheet(isPresented: sheetBinding) {
            if let post = viewModel.selectedPost {
                PostBottomCard(post: post, viewModel: viewModel)
                    .presentationDetents([Self.smallDetent, .medium])
                    .presentationBackgroundInteraction(.enabled(upThrough: Self.smallDetent))
                    .presentationDragIndicator(.visible)
            }
        }
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
                message: "Allow location to see where you are on campus. We only use it while GatorPlate is open, and it never leaves your phone.",
                actionTitle: "Allow location",
                action: viewModel.location.requestPermission
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
                action: viewModel.location.requestFullAccuracy
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
    CampusMapView(viewModel: PreviewSupport.mapViewModel())
        .environment(\.appEnvironment, .mock)
}

#Preview("Permission needed") {
    let model = PreviewSupport.mapViewModel()
    model.location.apply(status: .notDetermined)
    return CampusMapView(viewModel: model)
        .environment(\.appEnvironment, .mock)
}

#Preview("Off campus") {
    let model = PreviewSupport.mapViewModel()
    model.location.apply(location: Coordinate(latitude: 37.3349, longitude: -122.0090))
    return CampusMapView(viewModel: model)
        .environment(\.appEnvironment, .mock)
}
