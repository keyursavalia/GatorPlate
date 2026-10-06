import MapKit
import Observation
import OSLog
import SwiftUI

/// Drives the campus map: active posts, pin selection, camera and location banners.
@MainActor
@Observable
final class MapViewModel {
    enum LocationBanner: Hashable {
        case prePrompt, denied, restricted, reducedAccuracy
    }

    static let homeCamera = MapCamera(centerCoordinate: SFSUCampus.homeCoordinate.clLocationCoordinate,
                                      distance: SFSUCampus.homeCameraDistance)

    static let cameraBounds = MapCameraBounds(centerCoordinateBounds: SFSUCampus.cameraCenterRegion,
                                              minimumDistance: SFSUCampus.minCameraDistance,
                                              maximumDistance: SFSUCampus.maxCameraDistance)

    let location: any LocationProviding
    var cameraPosition: MapCameraPosition = .camera(MapViewModel.homeCamera)
    var selectedPostId: String?
    private(set) var loadErrorMessage: String?

    private var allPosts: [FoodPost] = []
    /// Bumped periodically so expired posts drop off the map.
    private var now = Date.now
    private var dismissedBanners: Set<LocationBanner> = []

    @ObservationIgnored private let postService: any PostService
    @ObservationIgnored private var postsTask: Task<Void, Never>?

    init(posts: any PostService, location: any LocationProviding) {
        self.postService = posts
        self.location = location
    }

    /// Active posts only: never trust `status` alone.
    var posts: [FoodPost] {
        allPosts.filter { $0.isActive(now: now) }
    }

    var selectedPost: FoodPost? {
        guard let selectedPostId else { return nil }
        return posts.first { $0.id == selectedPostId }
    }

    var locationBanner: LocationBanner? {
        let banner: LocationBanner? = switch location.authorization {
        case .notDetermined: .prePrompt
        case .denied: .denied
        case .restricted: .restricted
        case .authorized(precise: false): .reducedAccuracy
        case .authorized(precise: true): nil
        }
        guard let banner, !dismissedBanners.contains(banner) else { return nil }
        return banner
    }

    /// True when recenter goes to the user rather than to the campus.
    var canCenterOnUser: Bool {
        location.authorization.isAuthorized && location.isOnCampus
    }

    func onAppear() {
        location.startUpdates()
        guard postsTask == nil else { return }
        let stream = postService.observeActivePosts()
        postsTask = Task { [weak self] in
            do {
                for try await posts in stream {
                    self?.allPosts = posts
                    self?.loadErrorMessage = nil
                }
            } catch {
                Logger.ui.error("Map posts stream failed: \(String(describing: error), privacy: .public)")
                self?.loadErrorMessage = "Couldn't load free food right now."
            }
        }
    }

    func onDisappear() {
        location.stopUpdates()
        postsTask?.cancel()
        postsTask = nil
        selectedPostId = nil
    }

    func refreshClock(_ date: Date = .now) {
        now = date
        if selectedPostId != nil, selectedPost == nil { selectedPostId = nil }
    }

    func recenter() {
        cameraPosition = canCenterOnUser
            ? .userLocation(fallback: .camera(Self.homeCamera))
            : .camera(Self.homeCamera)
    }

    func enableLocation() {
        location.requestAuthorization()
    }

    func requestPreciseLocation() {
        location.requestTemporaryPreciseAccuracy()
    }

    func dismissBanner(_ banner: LocationBanner) {
        dismissedBanners.insert(banner)
    }

    /// "350 ft away" in the user's locale, or nil without a location fix.
    func distanceText(to post: FoodPost) -> String? {
        guard let meters = location.distance(to: post.coordinate) else { return nil }
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return "\(measurement.formatted(.measurement(width: .abbreviated, usage: .road))) away"
    }

    func accessibilityLabel(for post: FoodPost) -> String {
        let minutes = TimeRemainingPill.minutesLeft(until: post.expiresAt, now: now)
        let distance = distanceText(to: post) ?? "distance unknown"
        return "Free food: \(post.title), \(minutes) minutes left, \(distance)"
    }
}
