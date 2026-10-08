import Foundation

/// Walking directions. The user's coordinate goes only to the routing provider, never to our backend or logs.
@MainActor
protocol RoutingService {
    /// Throws `RouteFailure` (`.noRoute`, `.network`, `.throttled`, `.cancelled`, `.unknown`).
    func walkingRoute(from origin: Coordinate, to destination: Coordinate) async throws -> WalkingRoute
    /// Turn-by-turn walking directions in Apple Maps. Works without location permission.
    func openInAppleMaps(to destination: Coordinate, name: String)
}
