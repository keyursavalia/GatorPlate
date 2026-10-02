import Foundation

/// Plain coordinate so protocols and models stay free of CoreLocation.
nonisolated struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}
