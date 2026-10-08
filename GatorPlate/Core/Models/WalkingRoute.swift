import Foundation

/// A walking route as plain values, so no MapKit reference types leave the routing service.
nonisolated struct WalkingRoute: Equatable, Sendable {
    var coordinates: [Coordinate]
    var distanceMeters: Double
    var expectedTravelTime: TimeInterval
}
