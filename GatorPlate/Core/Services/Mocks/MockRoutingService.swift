import Foundation

@MainActor
final class MockRoutingService: RoutingService {
    /// Returned when set; otherwise a straight two-point route at walking speed.
    var route: WalkingRoute?
    var failure: RouteFailure?
    var delay: Duration = .milliseconds(400)
    private(set) var requestCount = 0
    private(set) var openedInMaps: [Coordinate] = []

    init(route: WalkingRoute? = nil, failure: RouteFailure? = nil) {
        self.route = route
        self.failure = failure
    }

    func walkingRoute(from origin: Coordinate, to destination: Coordinate) async throws -> WalkingRoute {
        requestCount += 1
        do {
            try await Task.sleep(for: delay)
        } catch {
            throw RouteFailure.cancelled
        }
        if let failure { throw failure }
        if let route { return route }
        let meters = origin.distance(to: destination)
        return WalkingRoute(coordinates: [origin, destination], distanceMeters: meters,
                            expectedTravelTime: meters / 1.4)
    }

    func openInAppleMaps(to destination: Coordinate, name: String) {
        openedInMaps.append(destination)
    }
}
