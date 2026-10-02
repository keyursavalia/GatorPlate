import MapKit
import SwiftUI

/// San Francisco State University campus geometry.
///
/// Bounds come from the OpenStreetMap footprint of the campus (lat 37.7197 to 37.7294, lon -122.4850 to -122.4752)
/// narrowed to the academic core plus a small margin, so the University Park North apartments are left out.
/// `MapCameraBounds` limits the camera CENTER, not the visible edge, so the zoom-out limit is kept small.
nonisolated enum SFSUCampus {
    static let center = Coordinate(latitude: 37.7235, longitude: -122.4800)
    static let latitudeSpan: Double = 0.0080
    static let longitudeSpan: Double = 0.0100

    /// Closest and farthest camera distance, in meters.
    static let minimumCameraDistance: Double = 150
    static let maximumCameraDistance: Double = 1500
    /// Distance used when the camera is reset to the whole campus.
    static let overviewCameraDistance: Double = 1300

    static var minLatitude: Double { center.latitude - latitudeSpan / 2 }
    static var maxLatitude: Double { center.latitude + latitudeSpan / 2 }
    static var minLongitude: Double { center.longitude - longitudeSpan / 2 }
    static var maxLongitude: Double { center.longitude + longitudeSpan / 2 }

    static var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
        )
    }

    static var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            centerCoordinateBounds: region,
            minimumDistance: minimumCameraDistance,
            maximumDistance: maximumCameraDistance
        )
    }

    static var overviewCamera: MapCamera {
        MapCamera(
            centerCoordinate: center.clCoordinate,
            distance: overviewCameraDistance,
            heading: 0,
            pitch: 0
        )
    }

    /// Edges are inclusive. Also used to validate post locations (Sprint 5).
    static func contains(_ coordinate: Coordinate) -> Bool {
        (minLatitude...maxLatitude).contains(coordinate.latitude)
            && (minLongitude...maxLongitude).contains(coordinate.longitude)
    }
}
