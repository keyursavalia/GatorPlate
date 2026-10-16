import MapKit
import SwiftUI

/// Campus map locked to SFSU with rotation, live post pins and a non-modal post sheet.
struct MapScreen: View {
    @Bindable var viewModel: MapViewModel
    /// First-run location and notification prompts; owns the "Alerts on" toast.
    let permissions: FirstRunPermissions
    let onPostFood: () -> Void

    @Namespace private var mapScope
    @State private var detent: PresentationDetent = Self.peekDetent
    /// The map's full drawn area in its own coordinates, safe areas included (the map draws under the bars).
    @State private var drawnRect = CGRect.zero
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Opens here: photo, title, the three facts and Open in Apple Maps. Pull up (or scroll) for the rest; the
    /// layout is the same at both heights.
    private static let peekDetent = PresentationDetent.fraction(0.62)
    private static let pointsOfInterest: [MKPointOfInterestCategory] = [
        .university, .library, .cafe, .restaurant, .bakery, .foodMarket,
        .park, .stadium, .restroom, .publicTransport,
    ]

    var body: some View {
        MapReader { proxy in
            map
                .onMapCameraChange(frequency: .onEnd) { context in
                    cameraDidEnd(context.camera, proxy: proxy)
                }
        }
        .onGeometryChange(for: CGRect.self) { geometry in
            let insets = geometry.safeAreaInsets
            return CGRect(x: -insets.leading, y: -insets.top,
                          width: geometry.size.width + insets.leading + insets.trailing,
                          height: geometry.size.height + insets.top + insets.bottom)
        } action: { rect in
            drawnRect = rect
        }
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
            if new != nil { detent = Self.peekDetent }
            viewModel.selectionDidChange()
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

    private var map: some View {
        Map(position: $viewModel.cameraPosition,
            bounds: viewModel.cameraBounds,
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
    }

    /// Reads the real visible north edge from the 4 drawn corners (exact for any heading, device or orientation)
    /// and moves the camera south when it overshoots. Only at rest (`.onEnd`), never while the finger is down.
    private func cameraDidEnd(_ camera: MapCamera, proxy: MapProxy) {
        let rect = drawnRect
        guard rect.width > 0, rect.height > 0 else { return }
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        let latitudes = corners.compactMap { proxy.convert($0, from: .local)?.latitude }
        guard latitudes.count == corners.count else { return }
        let correction = viewModel.cameraDidEnd(
            cornerLatitudes: latitudes, center: Coordinate(camera.centerCoordinate), distance: camera.distance,
            heading: camera.heading, metersPerPointPerMeter: metersPerPointPerMeter(proxy: proxy, camera: camera),
            viewSize: rect.size)
        guard let correction else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            viewModel.cameraPosition = .camera(correction)
        }
    }

    /// Meters per screen point at the center, measured 100 pt up, divided by the camera distance.
    private func metersPerPointPerMeter(proxy: MapProxy, camera: MapCamera) -> Double? {
        let mid = CGPoint(x: drawnRect.midX, y: drawnRect.midY)
        guard camera.distance > 0,
              let center = proxy.convert(mid, from: .local),
              let above = proxy.convert(CGPoint(x: mid.x, y: mid.y - 100), from: .local) else { return nil }
        let meters = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: above.latitude, longitude: above.longitude))
        return meters / 100 / camera.distance
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
            PostBottomCard(post: post, viewModel: viewModel)
                .presentationDetents([Self.peekDetent, .large], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: Self.peekDetent))
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
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
