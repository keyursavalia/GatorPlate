import MapKit
import SwiftUI

/// Campus map locked to SFSU with rotation, live post pins (filtered like the Feed) and a non-modal post sheet.
struct MapScreen: View {
    @Bindable var viewModel: MapViewModel
    /// First-run location and notification prompts; owns the "Notifications on" toast.
    let permissions: FirstRunPermissions
    let onPostFood: () -> Void
    /// A guest asked for an account from the Report sheet (opens once the post sheet has closed).
    var onRequestAccount: () -> Void = {}

    @Namespace private var mapScope
    @State private var detent: PresentationDetent = Self.peekDetent
    /// The map's full drawn area in its own coordinates, safe areas included (the map draws under the bars).
    @State private var drawnRect = CGRect.zero
    @State private var locationPrompt: LocationPrompt?
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
        .overlay {
            if viewModel.showsAlertUnavailable {
                UnavailableCard(onShowAvailable: viewModel.showAvailableFood,
                                onDismiss: viewModel.dismissAlertUnavailable)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35),
                   value: viewModel.showsAlertUnavailable)
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
        .sheet(isPresented: isSheetPresented, onDismiss: {
            if viewModel.postSheetDidDismiss() { onRequestAccount() }
        }) { bottomCard }
        .onChange(of: viewModel.selectedPostId) { _, new in
            if new != nil { detent = Self.peekDetent }
            viewModel.selectionDidChange()
        }
        .onChange(of: viewModel.cameraFocusPostId) { _, id in
            guard id != nil else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { viewModel.focusOnAlertPost() }
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
                    PostMapPin(post: post, isSelected: post.id == viewModel.selectedPostId, images: viewModel.images)
                        // Filter changes fade pins in and out; the camera never moves for them.
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
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
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: viewModel.posts.map(\.id))
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
            if viewModel.isOpeningAlert {
                Label("Opening post…", systemImage: "bell.badge")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .glassEffect(.regular, in: .capsule)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                    .accessibilityLabel("Opening the post from your notification")
            }
            if viewModel.showsFilterPill {
                FilterPill(shown: viewModel.posts.count, total: viewModel.browse.totalCount,
                           onOpen: viewModel.openFilters, onClear: viewModel.clearFilters)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
            RuntimeNotices(isGlass: true)
            VStack(spacing: Theme.Spacing.sm) {
                // One sheet at a time: hidden while a post's sheet is open.
                if viewModel.selectedPost == nil {
                    FilterButton(activeCount: viewModel.filterCount, action: viewModel.openFilters)
                }
                locationButton
                MapCompass(scope: mapScope)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.showsFilterPill)
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.isOpeningAlert)
        .sheet(isPresented: $viewModel.isFilterSheetPresented, onDismiss: viewModel.filterSheetDidDismiss) {
            PostFilterSheet(store: viewModel.browse.filters, browse: viewModel.browse, showsSort: false,
                            notificationPicks: viewModel.browse.notificationPicks)
        }
    }

    /// Centers on the student, or on campus. With location off it shows a slashed arrow and asks to turn it on.
    private var locationButton: some View {
        let label = viewModel.canCenterOnUser ? "Center on my location"
            : viewModel.isLocationOff ? "Location is off" : "Show whole campus"
        return GlassIconButton(
            systemImage: viewModel.canCenterOnUser ? "location.fill"
                : viewModel.isLocationOff ? "location.slash" : "building.columns",
            accessibilityLabel: label,
            accessibilityHint: viewModel.isLocationOff ? "Shows the whole campus and how to turn on location"
                                                       : "Moves the map") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { viewModel.recenter() }
                if viewModel.isLocationOff {
                    Task { locationPrompt = await viewModel.locationAccess.promptFromMap() }
                }
            }
            .locationPromptAlert($locationPrompt, access: viewModel.locationAccess)
    }

    private var alertsToast: some View {
        Toast(message: "Notifications on for all free food.", systemImage: "bell.badge.fill",
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
                // A new post (e.g. from an alert) resets the card, closing a Report sheet left open for the old one.
                .id(post.id)
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
}

#Preview("On campus") {
    let session = MainSession.preview
    MapScreen(viewModel: session.map, permissions: session.permissions, onPostFood: {})
}
