import MapKit
import Observation
import OSLog
import SwiftUI

/// The single banner shown above the map, highest priority first.
enum MapBanner: Equatable {
    case permissionPrompt
    case locationDenied
    case reducedAccuracy
    case offCampus
}

@MainActor
@Observable
final class MapViewModel {
    /// Closer than the overview, still shows the surroundings.
    static let userCameraDistance: Double = 450

    var cameraPosition: MapCameraPosition = .camera(SFSUCampus.overviewCamera)

    let repository: PostsRepository
    let location: UserLocationModel
    let navigation: NavigationModel
    let route: RouteViewModel
    let actions: PostActionsModel

    @ObservationIgnored private let routing: any RoutingService

    init(
        repository: PostsRepository,
        location: UserLocationModel,
        navigation: NavigationModel,
        routing: any RoutingService,
        actions: PostActionsModel
    ) {
        self.repository = repository
        self.location = location
        self.navigation = navigation
        self.routing = routing
        self.route = RouteViewModel(routing: routing)
        self.actions = actions
    }

    // MARK: Posts

    var selectedPostID: String? {
        get { navigation.selectedPostID }
        set { navigation.selectedPostID = newValue }
    }

    var activePosts: [FoodPost] { repository.posts }

    var selectedPost: FoodPost? {
        guard let selectedPostID else { return nil }
        return repository.post(id: selectedPostID)
    }

    func accessibilityLabel(for post: FoodPost, now: Date = Date()) -> String {
        let minutes = max(0, Int((post.expiresAt.timeIntervalSince(now) / 60).rounded(.up)))
        var label = "Free food: \(post.title), \(minutes) minutes left"
        if let distance = location.distanceText(to: post) {
            label += ", \(distance) away"
        }
        return label
    }

    // MARK: Banner

    var banner: MapBanner? {
        switch location.status.authorization {
        case .notDetermined: .permissionPrompt
        case .denied: .locationDenied
        case .authorized:
            if location.status.accuracy == .reduced {
                .reducedAccuracy
            } else if location.userLocation != nil && !location.isOnCampus {
                .offCampus
            } else {
                nil
            }
        }
    }

    // MARK: Route

    /// The route state for the selected post only: a route for another post is never shown.
    var routeState: RouteState {
        guard let postID = route.state.postID, postID == selectedPostID else { return .idle }
        return route.state
    }

    var visibleRoute: RouteSummary? {
        if case .routed(let summary) = routeState { summary } else { nil }
    }

    func startDirections() {
        guard let post = selectedPost else { return }
        route.requestRoute(to: post, from: location.userLocation)
    }

    func endRoute() {
        route.endRoute()
        recenter()
    }

    /// Puts the camera over the route (the Map's bounds keep it on campus).
    func fitCameraToRoute() {
        guard let summary = visibleRoute, let rect = RouteCamera.rect(for: summary.coordinates) else { return }
        cameraPosition = .rect(rect)
    }

    func openInAppleMaps() -> Bool {
        guard let post = selectedPost else { return false }
        return routing.openInAppleMaps(
            name: post.title,
            coordinate: Coordinate(latitude: post.latitude, longitude: post.longitude)
        )
    }

    // MARK: Reconciliation (call when the selection or the active posts change)

    func selectionChanged() {
        route.end(unlessFor: selectedPostID)
        actions.notice = nil
    }

    func postsChanged() {
        navigation.reconcile(activePostIDs: Set(repository.posts.map(\.id)), hasLoaded: repository.hasLoaded)
        route.end(unlessFor: selectedPostID)
    }

    // MARK: Camera

    /// On campus: fly to the user. Otherwise (off campus, no fix, no permission): the campus overview.
    func recenter() {
        if let userLocation = location.userLocation, SFSUCampus.contains(userLocation) {
            cameraPosition = .camera(
                MapCamera(centerCoordinate: userLocation.clCoordinate, distance: Self.userCameraDistance, heading: 0, pitch: 0)
            )
        } else {
            cameraPosition = .camera(SFSUCampus.overviewCamera)
        }
    }
}
