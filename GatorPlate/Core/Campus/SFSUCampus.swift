import CoreLocation
import MapKit

/// The SFSU campus area. Bounds come from the OpenStreetMap campus outline (way 28965902, including
/// University Park North) plus a ~40 m margin. See `docs/PROGRESS.md` for how they were verified.
nonisolated enum SFSUCampus {
    /// Middle of the campus bounds (1600 Holloway Ave resolves here too).
    static let center = Coordinate(latitude: 37.72455, longitude: -122.48011)

    /// Campus rectangle used by `contains`.
    static let region = MKCoordinateRegion(
        center: center.clLocationCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.0104, longitudeDelta: 0.0107))

    /// Where the camera center may go: `region` inset by ~150 m per side. `MapCameraBounds` limits the
    /// center, not the visible edge, so using the full region let the NE corner center on Stonestown.
    static let cameraCenterRegion = MKCoordinateRegion(
        center: center.clLocationCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.0077, longitudeDelta: 0.0073))

    /// Frames the academic core and UPN; shown when the map opens and on recenter when the user is off campus.
    static let homeCoordinate = Coordinate(latitude: 37.7240, longitude: -122.4801)

    /// Camera altitude limits in meters.
    static let minCameraDistance: CLLocationDistance = 120
    static let maxCameraDistance: CLLocationDistance = 3500
    static let homeCameraDistance: CLLocationDistance = 2800

    static func contains(_ coordinate: Coordinate) -> Bool {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        return abs(coordinate.latitude - region.center.latitude) <= halfLat
            && abs(coordinate.longitude - region.center.longitude) <= halfLon
    }

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        contains(Coordinate(coordinate))
    }
}
