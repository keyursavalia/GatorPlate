import Foundation
import Observation

/// Walking-route state for the selected post:
/// idle -> calculating -> active | failed, and back to idle on End route, a new selection or the post ending.
@MainActor
@Observable
final class RouteController {
    enum State: Equatable {
        case idle
        case calculating(postId: String)
        case active(postId: String, route: WalkingRoute)
        case failed(postId: String, RouteFailure)

        var postId: String? {
            switch self {
            case .idle: nil
            case .calculating(let postId), .active(let postId, _), .failed(let postId, _): postId
            }
        }
    }

    private(set) var state = State.idle

    @ObservationIgnored private let routing: any RoutingService
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let locationWait: Duration
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Bumped on every request and on end, so a late result for an old request is dropped.
    @ObservationIgnored private var generation = 0

    init(routing: any RoutingService, location: any LocationProviding,
         locationWait: Duration = .seconds(AppConfig.routeLocationWaitSeconds)) {
        self.routing = routing
        self.location = location
        self.locationWait = locationWait
    }

    var route: WalkingRoute? {
        if case .active(_, let route) = state { route } else { nil }
    }

    /// The route may start a little off with approximate location.
    var isApproximate: Bool {
        location.authorization == .authorized(precise: false)
    }

    func state(for postId: String) -> State {
        state.postId == postId ? state : .idle
    }

    func requestDirections(to post: FoodPost) {
        task?.cancel()
        generation += 1
        let generation = generation

        if let failure = RoutePreflight.check(authorization: location.authorization) {
            state = .failed(postId: post.id, failure)
            return
        }
        state = .calculating(postId: post.id)
        let destination = post.coordinate
        task = Task { [weak self] in
            guard let self else { return }
            let next = await self.calculate(postId: post.id, to: destination)
            guard generation == self.generation, !Task.isCancelled else { return }
            self.state = next
            self.task = nil
        }
    }

    /// End route: clears the polyline and cancels a request in flight.
    func end() {
        task?.cancel()
        task = nil
        generation += 1
        if state != .idle { state = .idle }
    }

    /// Call when the selection changes or a post leaves the map.
    func selectionDidChange(to postId: String?) {
        guard let routePostId = state.postId, routePostId != postId else { return }
        end()
    }

    private func calculate(postId: String, to destination: Coordinate) async -> State {
        let origin = await waitForOrigin()
        if let failure = RoutePreflight.check(origin: origin) { return .failed(postId: postId, failure) }
        guard let origin else { return .failed(postId: postId, .locationUnavailable) }
        do {
            let route = try await routing.walkingRoute(from: origin, to: destination)
            return .active(postId: postId, route: route)
        } catch let failure as RouteFailure {
            return .failed(postId: postId, failure)
        } catch {
            return .failed(postId: postId, .unknown)
        }
    }

    /// The last fix, or the first one to arrive within `locationWait` (the map keeps updates running).
    private func waitForOrigin() async -> Coordinate? {
        if let coordinate = location.lastCoordinate { return coordinate }
        location.startUpdates()
        let deadline = ContinuousClock.now + locationWait
        while ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            if let coordinate = location.lastCoordinate { return coordinate }
        }
        return nil
    }
}
