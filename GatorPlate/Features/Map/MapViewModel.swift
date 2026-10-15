import MapKit
import Observation
import OSLog
import SwiftUI

/// Drives the campus map: live pins, selection, the walking route, poster/report actions and location banners.
@MainActor
@Observable
final class MapViewModel {
    /// No "not asked yet" banner: the system prompt fires on its own (`FirstRunPermissions`).
    enum LocationBanner: String, Hashable {
        case denied, restricted, reducedAccuracy
    }

    enum ActionStatus: Equatable {
        case idle, working, failed(String)
    }

    static let homeCamera = MapCamera(centerCoordinate: SFSUCampus.homeCoordinate.clLocationCoordinate,
                                      distance: SFSUCampus.homeCameraDistance)

    static let staticCameraBounds = MapCameraBounds(centerCoordinateBounds: SFSUCampus.cameraCenterRegion,
                                                    minimumDistance: SFSUCampus.minCameraDistance,
                                                    maximumDistance: SFSUCampus.maxCameraDistance)

    let location: any LocationProviding
    let route: RouteController
    let images: PostImageCache?
    var cameraPosition: MapCameraPosition = .camera(MapViewModel.homeCamera)
    /// The Map tab is on screen (drives the first-run permission prompts).
    private(set) var isVisible = false
    /// Center limit for MapKit; its north edge follows the zoom (see `MapViewModel+Viewport`).
    var cameraBounds = MapViewModel.staticCameraBounds
    /// Last measured camera at rest, for the DEBUG bounds overlay.
    var viewport: ViewportReadout?
    @ObservationIgnored var boundsNorthLatitude = SFSUCampus.cameraCenterNorthLatitude
    @ObservationIgnored var boundsMaxDistance = SFSUCampus.maxCameraDistance
    private(set) var markGoneStatus = ActionStatus.idle
    private(set) var reportStatus = ActionStatus.idle
    /// Posts reported in this session: Report turns into "Thanks, we'll review it."
    private(set) var reportedPostIds: Set<String> = []

    /// Bumped on "Not now" so `locationBanner` re-reads the stored dismissals.
    private var dismissalCount = 0
    @ObservationIgnored private let dismissals: BannerDismissals

    @ObservationIgnored private let repository: PostsRepository
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let postService: any PostService
    @ObservationIgnored private let routing: any RoutingService
    @ObservationIgnored private let currentUid: String?

    init(repository: PostsRepository, navigation: AppNavigation, postService: any PostService,
         routing: any RoutingService, location: any LocationProviding, images: PostImageCache?,
         currentUid: String?, dismissals: BannerDismissals = BannerDismissals()) {
        self.dismissals = dismissals
        self.repository = repository
        self.navigation = navigation
        self.postService = postService
        self.routing = routing
        self.location = location
        self.images = images
        self.currentUid = currentUid
        self.route = RouteController(routing: routing, location: location)
    }

    var posts: [FoodPost] { repository.activePosts }

    var selectedPostId: String? {
        get { navigation.selectedPostId }
        set { navigation.selectedPostId = newValue }
    }

    var selectedPost: FoodPost? {
        selectedPostId.flatMap(repository.post(id:))
    }

    var loadErrorMessage: String? {
        repository.hasError ? "Couldn't load free food right now. Retrying..." : nil
    }

    /// "That food post has ended." and similar, shown briefly over the map.
    var notice: String? { navigation.notice }

    var locationBanner: LocationBanner? {
        let banner: LocationBanner? = switch location.authorization {
        case .notDetermined: nil
        case .denied: .denied
        case .restricted: .restricted
        case .authorized(precise: false): .reducedAccuracy
        case .authorized(precise: true): nil
        }
        _ = dismissalCount
        guard let banner, !dismissals.isSnoozed(banner.rawValue) else { return nil }
        return banner
    }

    /// True when recenter goes to the user rather than to the campus.
    var canCenterOnUser: Bool {
        location.authorization.isAuthorized && location.isOnCampus
    }

    func isOwnPost(_ post: FoodPost) -> Bool {
        currentUid == post.authorUid
    }

    // MARK: Lifecycle

    func onAppear() {
        isVisible = true
        location.startUpdates()
    }

    func onDisappear() {
        isVisible = false
        location.stopUpdates()
        selectedPostId = nil
        route.end()
    }

    /// Selection changed (pin tap, feed, deep link, or the post ended).
    func selectionDidChange() {
        route.selectionDidChange(to: selectedPostId)
        markGoneStatus = .idle
        reportStatus = .idle
    }

    func dismissNotice() {
        navigation.dismissNotice()
    }

    /// The "Customize" action on the alerts toast.
    func openAlertFilters() {
        navigation.openAlertFilters()
    }

    // MARK: Camera

    func recenter() {
        cameraPosition = canCenterOnUser
            ? .userLocation(fallback: .camera(Self.homeCamera))
            : .camera(Self.homeCamera)
    }

    /// Fits the active route above the sheet. `cameraBounds` still clamps it and the north-edge check may nudge
    /// it south, so the campus lock holds.
    func fitRouteIfActive() {
        guard let route = route.route else { return }
        cameraPosition = .rect(RouteFraming.rect(for: route.coordinates))
    }

    // MARK: Directions

    func requestDirections(to post: FoodPost) {
        route.requestDirections(to: post)
    }

    func endRoute() {
        route.end()
    }

    func openInAppleMaps(_ post: FoodPost) {
        routing.openInAppleMaps(to: post.coordinate, name: post.locationName)
    }

    // MARK: Poster and report actions

    func markGone(_ post: FoodPost) async {
        guard isOwnPost(post), markGoneStatus != .working else { return }
        markGoneStatus = .working
        navigation.expectRemoval(of: post.id)
        do {
            try await postService.markGone(postId: post.id)
            markGoneStatus = .idle
            Logger.ui.info("Post marked as gone")
        } catch {
            navigation.cancelExpectedRemoval(of: post.id)
            markGoneStatus = .failed(Self.actionMessage(for: error))
        }
    }

    /// True when the report was sent.
    func report(_ post: FoodPost, reason: ReportReason, note: String) async -> Bool {
        guard reportStatus != .working else { return false }
        reportStatus = .working
        do {
            try await postService.report(postId: post.id, reason: reason.reportText(note: note))
            reportedPostIds.insert(post.id)
            reportStatus = .idle
            return true
        } catch {
            reportStatus = .failed(Self.actionMessage(for: error))
            return false
        }
    }

    private static func actionMessage(for error: Error) -> String {
        switch error as? AppError {
        case .network: "Couldn't reach the server. Check your connection and try again."
        case .validation(let message): message
        case .permissionDenied: AppError.permissionDenied.userMessage
        default: AppError.unknown.userMessage
        }
    }

    // MARK: Location

    func requestPreciseLocation() {
        location.requestTemporaryPreciseAccuracy()
    }

    /// "Not now": hidden for `AppConfig.locationBannerSnoozeDays`, across launches.
    func dismissBanner(_ banner: LocationBanner) {
        dismissals.dismiss(banner.rawValue)
        dismissalCount += 1
    }

    // MARK: Text

    /// "350 ft away" in the user's locale, or nil without a location fix.
    func distanceText(to post: FoodPost) -> String? {
        DistanceText.away(meters: location.distance(to: post.coordinate))
    }

    /// Computed at render time, so the expiry tick never re-renders pins.
    func accessibilityLabel(for post: FoodPost) -> String {
        PostCard.accessibilityLabel(for: post, distanceText: distanceText(to: post))
    }
}
