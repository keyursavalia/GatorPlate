import MapKit
import SwiftUI

/// Campus map locked to SFSU with rotation, post pins and a non-modal bottom card.
struct MapScreen: View {
    @Bindable var viewModel: MapViewModel

    @Namespace private var mapScope
    @State private var detent: PresentationDetent = Self.smallDetent
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let smallDetent = PresentationDetent.fraction(0.3)
    private static let pointsOfInterest: [MKPointOfInterestCategory] = [
        .university, .library, .cafe, .restaurant, .bakery, .foodMarket,
        .park, .stadium, .restroom, .publicTransport,
    ]

    var body: some View {
        Map(position: $viewModel.cameraPosition,
            bounds: MapViewModel.cameraBounds,
            interactionModes: [.pan, .zoom, .rotate],
            selection: $viewModel.selectedPostId,
            scope: mapScope) {
            UserAnnotation()

            ForEach(viewModel.posts) { post in
                Annotation(post.title, coordinate: post.coordinate.clLocationCoordinate) {
                    PostPin(dietary: post.overallDietary, isSelected: post.id == viewModel.selectedPostId)
                        .accessibilityLabel(viewModel.accessibilityLabel(for: post))
                        .accessibilityHint("Shows details")
                        .accessibilityAddTraits(.isButton)
                }
                .tag(post.id)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .including(Self.pointsOfInterest)))
        .mapControls {}
        .overlay(alignment: .top) { topOverlay }
        .mapScope(mapScope)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.selectedPostId) { _, new in new != nil }
        .sheet(isPresented: isSheetPresented) { bottomCard }
        .onChange(of: viewModel.selectedPostId) { _, new in
            if new != nil { detent = Self.smallDetent }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .task {
            // Drop expired posts while the map is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                viewModel.refreshClock()
            }
        }
    }

    private var topOverlay: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.sm) {
            if let message = viewModel.loadErrorMessage {
                solidBanner(Banner(style: .error, message: message))
            }
            if let banner = viewModel.locationBanner {
                locationBanner(banner)
            }
            VStack(spacing: Theme.Spacing.sm) {
                GlassIconButton(
                    systemImage: viewModel.canCenterOnUser ? "location.fill" : "building.columns",
                    accessibilityLabel: viewModel.canCenterOnUser ? "Center on my location" : "Show whole campus",
                    accessibilityHint: "Moves the map") {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { viewModel.recenter() }
                    }
                MapCompass(scope: mapScope)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    @ViewBuilder
    private func locationBanner(_ banner: MapViewModel.LocationBanner) -> some View {
        let notNow = Banner.Action(title: "Not now", isPrimary: false) { viewModel.dismissBanner(banner) }
        switch banner {
        case .prePrompt:
            solidBanner(Banner(
                style: .info,
                message: "See how far free food is from you. GatorPlate uses your location only while the map is open.",
                actions: [Banner.Action(title: "Enable location") { viewModel.enableLocation() }, notNow]))
        case .denied:
            solidBanner(Banner(
                style: .warning,
                message: "Location is off. The map still works, but distances are hidden.",
                actions: [Banner.Action(title: "Open Settings") { openSettings() }, notNow]))
        case .restricted:
            solidBanner(Banner(
                style: .warning,
                message: "Location is restricted on this device. The map still works, but distances are hidden.",
                actions: [notNow]))
        case .reducedAccuracy:
            solidBanner(Banner(
                style: .warning,
                message: "Precise location is off, directions may be less accurate.",
                actions: [Banner.Action(title: "Use precise location") { viewModel.requestPreciseLocation() }, notNow]))
        }
    }

    /// Opaque backing so banner text stays readable over the map (glass is for controls only).
    private func solidBanner(_ banner: Banner) -> some View {
        banner.background(.background, in: .rect(cornerRadius: Theme.Radius.photo))
    }

    @ViewBuilder
    private var bottomCard: some View {
        if let post = viewModel.selectedPost {
            PostBottomCard(post: post,
                           distanceText: viewModel.distanceText(to: post),
                           isExpanded: detent == .medium)
                .presentationDetents([Self.smallDetent, .medium], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                // Solid, not glass: the card is content (design system: glass on controls only).
                .presentationBackground(.background)
        }
    }

    private var isSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.selectedPost != nil },
            set: { isPresented in
                if !isPresented { viewModel.selectedPostId = nil }
            })
    }

    private func openSettings() {
        guard let url = AppSettingsURL.url else { return }
        openURL(url)
    }
}

#Preview("On campus") {
    MapScreen(viewModel: MapViewModel(posts: MockPostService(posts: FoodPost.mockCampus),
                                      location: MockLocationProvider()))
}

#Preview("Not asked yet") {
    MapScreen(viewModel: MapViewModel(posts: MockPostService(posts: FoodPost.mockCampus),
                                      location: MockLocationProvider(authorization: .notDetermined)))
}

#Preview("Approximate location") {
    MapScreen(viewModel: MapViewModel(posts: MockPostService(posts: FoodPost.mockCampus),
                                      location: MockLocationProvider(authorization: .authorized(precise: false))))
}

#Preview("Denied") {
    MapScreen(viewModel: MapViewModel(posts: MockPostService(posts: FoodPost.mockCampus),
                                      location: MockLocationProvider(authorization: .denied)))
}
