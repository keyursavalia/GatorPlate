import Foundation

/// A walking route reduced to plain values, so view models and tests never touch MapKit types.
nonisolated struct WalkingRoute: Equatable, Sendable {
    var coordinates: [Coordinate]
    var distanceMeters: Double
    var travelTime: TimeInterval
}

nonisolated enum RoutingError: Error, Equatable, Sendable {
    /// MapKit has no walking route between the two points.
    case noRoute
    /// The directions request could not complete (offline, throttled, server failure).
    case network
}

nonisolated protocol RoutingService: Sendable {
    /// Walking route from `from` to `to`. Cancelling the calling task cancels the request.
    func walkingRoute(from: Coordinate, to: Coordinate) async throws -> WalkingRoute

    /// Opens Apple Maps with walking directions to the coordinate. Returns false if Maps could not be opened.
    @MainActor func openInAppleMaps(name: String, coordinate: Coordinate) -> Bool
}
