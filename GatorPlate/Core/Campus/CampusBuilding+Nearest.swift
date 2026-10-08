import Foundation

nonisolated extension CampusBuilding {
    /// Closest catalog building by straight-line distance.
    static func nearest(to coordinate: Coordinate) -> CampusBuilding? {
        all.min { $0.coordinate.distance(to: coordinate) < $1.coordinate.distance(to: coordinate) }
    }
}
