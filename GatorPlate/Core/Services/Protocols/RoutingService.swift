import Foundation

/// Directions hand off to Apple Maps; GatorPlate doesn't draw routes itself. No coordinate reaches our backend
/// or logs.
@MainActor
protocol RoutingService {
    /// Turn-by-turn walking directions in Apple Maps. Works without location permission.
    func openInAppleMaps(to destination: Coordinate, name: String)
}
