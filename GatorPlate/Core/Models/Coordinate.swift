import Foundation

/// Plain lat/long pair so protocols stay free of CoreLocation types.
nonisolated struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}
