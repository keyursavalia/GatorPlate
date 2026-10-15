import MapKit
import SwiftUI

/// Campus map locked to SFSU with rotation, live post pins, a walking route and a non-modal bottom card.
struct MapScreen: View {
    @Bindable var viewModel: MapViewModel
    /// First-run location and notification prompts; owns the "Alerts on" toast.
    let permissions: FirstRunPermissions
    let onPostFood: () -> Void

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

            if let route = viewModel.route.route {
                MapPolyline(coordinates: route.coordinates.map(\.clLocationCoordinate))
                    .stroke(Theme.Palette.brandPurple,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .mapOverlayLevel(level: .aboveRoads)
            }

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
        .overlay(alignment: .bottomTrailing) {
            // Hidden while the bottom card is up: the cover can't present over the sheet.
            if viewModel.selectedPost == nil {
                VStack(alignment: .trailing, spacing: Theme.Spacing.md) {
                    if permissions.showsAlertsToast {
                        alertsToast.transition(.opacity)
                    }
                    PostFAB(action: onPostFood)
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .mapScope(mapScope)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.selectedPostId) { _, new in new != nil }
        .sheet(isPresented: isSheetPresented) { bottomCard }
        .onChange(of: viewModel.selectedPostId) { _, new in
            if new != nil { detent = Self.smallDetent }
            viewModel.selectionDidChange()
        }
        .onChange(of: viewModel.route.state) { _, new in
            routeDidChange(new)
        }
        .onChange(of: permissions.announcement) { _, announcement in
            guard let announcement else { return }
            AccessibilityNotification.Announcement(announcement).post()
            permissions.clearAnnouncement()
        }
        .animation(reduceMotion ? nil : .easeInOut, value: permissions.showsAlertsToast)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .task(id: viewModel.notice) {
            guard let notice = viewModel.notice else { return }
            AccessibilityNotification.Announcement(notice).post()
            try? await Task.sleep(for: .seconds(AppConfig.mapNoticeSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut) { viewModel.dismissNotice() }
        }
    }

    private func routeDidChange(_ state: RouteController.State) {
        switch state {
        case .active(_, let route):
            // Smaller sheet so the route stays visible.
            detent = Self.smallDetent
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { viewModel.fitRouteIfActive() }
            AccessibilityNotification.Announcement(
                "Route ready, \(DistanceText.walkMinutes(seconds: route.expectedTravelTime)) minute walk").post()
        case .failed(_, let failure):
            AccessibilityNotification.Announcement(failure.userMessage).post()
        case .idle, .calculating:
            break
        }
    }

    private var topOverlay: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.sm) {
            if let message = viewModel.loadErrorMessage {
                solidBanner(Banner(style: .error, message: message))
            }
            if let notice = viewModel.notice {
                solidBanner(Banner(style: .info, message: notice))
                    .transition(.opacity)
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

    private var alertsToast: some View {
        Toast(message: "Alerts on for all free food.", systemImage: "bell.badge.fill",
              action: Toast.Action(title: "Customize") { viewModel.openAlertFilters() },
              onDismiss: { permissions.dismissAlertsToast() })
    }

    /// Opaque backing so banner text stays readable over the map (glass is for controls only).
    private func solidBanner(_ banner: Banner) -> some View {
        banner.background(.background, in: .rect(cornerRadius: Theme.Radius.photo))
    }

    @ViewBuilder
    private var bottomCard: some View {
        if let post = viewModel.selectedPost {
            PostBottomCard(post: post, viewModel: viewModel, isExpanded: detent == .medium)
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
    let session = MainSession.preview
    MapScreen(viewModel: session.map, permissions: session.permissions, onPostFood: {})
}
