import Foundation
import Observation

enum RouteFailure: Equatable {
    case noLocation
    case offCampus
    case noRoute
    case network

    /// Shown in the bottom card. "Open in Maps" is always offered next to it.
    var message: String {
        switch self {
        case .noLocation: "Turn on location to see a walking route here, or open Apple Maps."
        case .offCampus: "You're off campus, so the route can't be shown here. Open Apple Maps for directions."
        case .noRoute: "We couldn't find a walking route. Try Apple Maps."
        case .network: "We couldn't load directions. Check your connection and try again."
        }
    }

    var canRetry: Bool { self == .noRoute || self == .network }
}

struct RouteSummary: Equatable {
    var postID: String
    var coordinates: [Coordinate]
    var distanceMeters: Double
    var travelTime: TimeInterval
}

/// idle -> loading -> routed -> idle (ended), with failure branches. "Ended" is simply `idle` again.
enum RouteState: Equatable {
    case idle
    case loading(postID: String)
    case routed(RouteSummary)
    case failed(postID: String, RouteFailure)

    var postID: String? {
        switch self {
        case .idle: nil
        case .loading(let postID), .failed(let postID, _): postID
        case .routed(let summary): summary.postID
        }
    }
}

@MainActor
@Observable
final class RouteViewModel {
    private(set) var state: RouteState = .idle

    @ObservationIgnored private let routing: any RoutingService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(routing: any RoutingService) {
        self.routing = routing
    }

    /// One calculation per request: no re-routing as the user walks. A new request replaces any in flight.
    func requestRoute(to post: FoodPost, from user: Coordinate?) {
        task?.cancel()
        task = nil

        guard let user else {
            state = .failed(postID: post.id, .noLocation)
            return
        }
        // A route that leaves campus could not be shown inside the locked map.
        guard SFSUCampus.contains(user) else {
            state = .failed(postID: post.id, .offCampus)
            return
        }

        let postID = post.id
        let destination = Coordinate(latitude: post.latitude, longitude: post.longitude)
        state = .loading(postID: postID)
        task = Task { [routing, weak self] in
            do {
                let route = try await routing.walkingRoute(from: user, to: destination)
                self?.finish(postID: postID, with: .routed(RouteSummary(
                    postID: postID,
                    coordinates: route.coordinates,
                    distanceMeters: route.distanceMeters,
                    travelTime: route.travelTime
                )))
            } catch is CancellationError {
                // Replaced or ended: whoever cancelled already set the state.
            } catch RoutingError.noRoute {
                self?.finish(postID: postID, with: .failed(postID: postID, .noRoute))
            } catch {
                self?.finish(postID: postID, with: .failed(postID: postID, .network))
            }
        }
    }

    /// Ignores a result that no longer belongs to the current request (latest request wins).
    private func finish(postID: String, with newState: RouteState) {
        guard case .loading(let current) = state, current == postID else { return }
        state = newState
        task = nil
    }

    func endRoute() {
        task?.cancel()
        task = nil
        state = .idle
    }

    /// Ends the route unless it belongs to `postID`. Used when the selection changes or the post goes away.
    func end(unlessFor postID: String?) {
        guard let current = state.postID, current != postID else { return }
        endRoute()
    }

    /// Test hook: waits for the in-flight request.
    func waitForCompletion() async {
        await task?.value
    }
}
