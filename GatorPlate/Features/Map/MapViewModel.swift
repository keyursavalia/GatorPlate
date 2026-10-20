import MapKit
import Observation
import OSLog
import SwiftUI

/// Drives the campus map: live pins (through the Map/Feed filter), selection, Apple Maps directions, poster/report
/// actions, and asking for location from the location button (`LocationAccess`).
@MainActor
@Observable
final class MapViewModel {
    enum ActionStatus: Equatable {
        case idle, working, failed(String)
    }

    static let homeCamera = MapCamera(centerCoordinate: SFSUCampus.homeCoordinate.clLocationCoordinate,
                                      distance: SFSUCampus.homeCameraDistance)

    static let staticCameraBounds = MapCameraBounds(centerCoordinateBounds: SFSUCampus.cameraCenterRegion,
                                                    minimumDistance: SFSUCampus.minCameraDistance,
                                                    maximumDistance: SFSUCampus.maxCameraDistance)

    let location: any LocationProviding
    /// Location on/off, shared with Settings > Location.
    let locationAccess: LocationAccess
    let images: PostImageCache?
    /// The shared Map/Feed filter and the posts it lets through.
    let browse: BrowseResults
    var cameraPosition: MapCameraPosition = .camera(MapViewModel.homeCamera)
    /// The Map tab is on screen (drives the first-run permission prompts).
    private(set) var isVisible = false
    /// Center limit for MapKit; its north edge follows the zoom (see `MapViewModel+Viewport`).
    var cameraBounds = MapViewModel.staticCameraBounds
    @ObservationIgnored var boundsNorthLatitude = SFSUCampus.cameraCenterNorthLatitude
    @ObservationIgnored var boundsMaxDistance = SFSUCampus.maxCameraDistance
    private(set) var markGoneStatus = ActionStatus.idle
    private(set) var reportStatus = ActionStatus.idle
    /// Posts this account reported (kept until they end): Report turns into "Thanks, we'll review it."
    let reportedPosts: ReportedPosts
    /// Reporting needs a verified account (`firestore.rules`); guests see a "Create a free account" prompt.
    var canReport = false
    /// A guest chose "Create a free account" on the Report sheet: the account flow opens once the post sheet closes.
    @ObservationIgnored private var opensAccountAfterSheet = false

    @ObservationIgnored private let repository: PostsRepository
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let postService: any PostService
    @ObservationIgnored private let routing: any RoutingService
    @ObservationIgnored private let currentUid: String?

    init(repository: PostsRepository, navigation: AppNavigation, postService: any PostService,
         routing: any RoutingService, location: any LocationProviding, locationAccess: LocationAccess,
         images: PostImageCache?, browse: BrowseResults, reportedPosts: ReportedPosts, currentUid: String?) {
        self.repository = repository
        self.navigation = navigation
        self.postService = postService
        self.routing = routing
        self.location = location
        self.locationAccess = locationAccess
        self.images = images
        self.browse = browse
        self.reportedPosts = reportedPosts
        self.currentUid = currentUid
    }

    /// Pins: the posts the filter lets through, plus the open post even when the filter would hide it.
    var posts: [FoodPost] { browse.posts }

    // MARK: Filters

    var filterCount: Int { browse.filters.filter.activeCount }

    /// The filter sheet (closed by a tapped alert before its post opens).
    var isFilterSheetPresented: Bool {
        get { navigation.filterSheetTab == .map }
        set { navigation.filterSheetTab = newValue ? .map : nil }
    }

    /// "Filtered · 3 of 7" over the map: only while the filter hides something.
    var showsFilterPill: Bool { browse.hiddenCount > 0 }

    func openFilters() {
        isFilterSheetPresented = true
    }

    func clearFilters() {
        browse.filters.clear()
    }

    func filterSheetDidDismiss() {
        navigation.filterSheetDidDismiss()
    }

    /// "Hidden by your filters" in the sheet of a post that was opened on purpose.
    func isHiddenByFilters(_ post: FoodPost) -> Bool {
        browse.isHiddenByFilters(post)
    }

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

    /// A tapped alert's post is being looked up ("Opening post…").
    var isOpeningAlert: Bool { navigation.isOpeningAlert }

    /// A tapped alert's post is gone: the centered "no longer available" card.
    var showsAlertUnavailable: Bool { navigation.showsAlertUnavailable }

    func dismissAlertUnavailable() {
        navigation.dismissAlertUnavailable()
    }

    func showAvailableFood() {
        navigation.showAvailableFood()
    }

    /// Denied or restricted: the location button shows "location off" and explains how to turn it on.
    var isLocationOff: Bool {
        location.authorization == .denied || location.authorization == .restricted
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
        focusOnAlertPost()
    }

    func onDisappear() {
        isVisible = false
        location.stopUpdates()
        selectedPostId = nil
    }

    /// Selection changed (pin tap, feed, deep link, or the post ended).
    func selectionDidChange() {
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

    /// An alert opened this post: frame it above the sheet. The camera bounds keep it inside the campus lock.
    func focusOnAlertPost() {
        guard let id = navigation.cameraFocusPostId else { return }
        navigation.clearCameraFocus()
        guard let post = repository.post(id: id) else { return }
        let span = AppConfig.alertOpenRegionSpanDegrees
        // The pin sits about a fifth of the way down, clear of the sheet over the lower part of the map.
        let center = CLLocationCoordinate2D(latitude: post.coordinate.latitude - span * 0.3,
                                            longitude: post.coordinate.longitude)
        cameraPosition = .region(MKCoordinateRegion(
            center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span / 3)))
    }

    var cameraFocusPostId: String? { navigation.cameraFocusPostId }

    func recenter() {
        cameraPosition = canCenterOnUser
            ? .userLocation(fallback: .camera(Self.homeCamera))
            : .camera(Self.homeCamera)
    }

    // MARK: Directions

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

    /// True when the report was sent. The post is hidden from this account's Map and Feed right away.
    func report(_ post: FoodPost, category: ReportCategory, reason: String) async -> Bool {
        guard reportStatus != .working else { return false }
        reportStatus = .working
        do {
            try await postService.report(postId: post.id, category: category, reason: reason)
            reportedPosts.insert(post)
            reportStatus = .idle
            Logger.ui.info("Post reported (\(category.rawValue, privacy: .public))")
            return true
        } catch {
            reportStatus = .failed(Self.actionMessage(for: error))
            return false
        }
    }

    /// "Create a free account" on the Report sheet: closes the post sheet; `postSheetDidDismiss` then asks for the
    /// account flow (a cover can't open over the sheet).
    func requestAccountToReport() {
        opensAccountAfterSheet = true
        selectedPostId = nil
    }

    /// The post sheet's `onDismiss`. True when the account flow should open now.
    func postSheetDidDismiss() -> Bool {
        defer { opensAccountAfterSheet = false }
        return opensAccountAfterSheet
    }

    private static func actionMessage(for error: Error) -> String {
        switch error as? AppError {
        case .network: "Couldn't reach the server. Check your connection and try again."
        case .validation(let message): message
        case .permissionDenied: AppError.permissionDenied.userMessage
        default: AppError.unknown.userMessage
        }
    }

    // MARK: Text

    /// "350 ft away" in the user's locale, or nil without a location fix.
    func distanceText(to post: FoodPost) -> String? {
        DistanceText.away(meters: location.distance(to: post.coordinate))
    }

    /// Computed at render time, so the expiry tick never re-renders pins.
    func accessibilityLabel(for post: FoodPost) -> String {
        PostRow.accessibilityLabel(for: post, distanceText: distanceText(to: post))
    }
}
