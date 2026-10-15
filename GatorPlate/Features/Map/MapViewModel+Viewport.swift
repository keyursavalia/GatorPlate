import CoreGraphics
import MapKit
import SwiftUI

/// The camera at rest: its real visible north edge (from the 4 view corners), distance and heading.
struct ViewportReadout: Equatable {
    var northEdge: Double
    var distance: Double
    var heading: Double

    var isWithinLimit: Bool {
        CampusViewport.northExcess(cornerLatitudes: [northEdge], limit: SFSUCampus.northVisibleLimit)
            <= AppConfig.mapNorthToleranceMeters
    }
}

/// North edge at Stonestown: adaptive center bounds (layer 2) and the rubber band (layer 3).
extension MapViewModel {
    /// Call when a camera change ends (gesture or programmatic). Returns a camera to animate to when the visible
    /// north edge is more than the tolerance past the limit; the correction's own end then finds no excess, so
    /// it never loops.
    func cameraDidEnd(cornerLatitudes: [Double], center: Coordinate, distance: Double, heading: Double,
                      metersPerPointPerMeter: Double?, viewSize: CGSize) -> MapCamera? {
        guard let northEdge = cornerLatitudes.max() else { return nil }
        viewport = ViewportReadout(northEdge: northEdge, distance: distance, heading: heading)
        if AppConfig.mapAdaptiveCenterBounds, let metersPerPointPerMeter, viewSize.width > 0 {
            updateBounds(distance: distance, metersPerPointPerMeter: metersPerPointPerMeter, viewSize: viewSize)
        }
        let excess = CampusViewport.northExcess(cornerLatitudes: cornerLatitudes, limit: SFSUCampus.northVisibleLimit)
        guard excess > AppConfig.mapNorthToleranceMeters else { return nil }
        let corrected = CampusViewport.correctedCenter(center,
                                                       excessMeters: excess + AppConfig.mapCorrectionPaddingMeters)
        return MapCamera(centerCoordinate: corrected.clLocationCoordinate, distance: distance, heading: heading,
                         pitch: 0)
    }

    /// MapKit then blocks panning north natively at this zoom. Reassigned only on a real change, so the map
    /// doesn't re-render on every gesture.
    private func updateBounds(distance: Double, metersPerPointPerMeter: Double, viewSize: CGSize) {
        let south = SFSUCampus.cameraCenterSouthLatitude
        let north = max(south + 0.0005,
                        CampusViewport.adaptiveCenterNorthLimit(distance: distance,
                                                                metersPerPointPerMeter: metersPerPointPerMeter,
                                                                viewSize: viewSize))
        let maxDistance = CampusViewport.adaptiveMaxDistance(metersPerPointPerMeter: metersPerPointPerMeter,
                                                             viewSize: viewSize)
        guard abs(north - boundsNorthLatitude) > 0.00002 || abs(maxDistance - boundsMaxDistance) > 5 else { return }
        boundsNorthLatitude = north
        boundsMaxDistance = maxDistance
        let staticRegion = SFSUCampus.cameraCenterRegion
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (north + south) / 2, longitude: staticRegion.center.longitude),
            span: MKCoordinateSpan(latitudeDelta: north - south, longitudeDelta: staticRegion.span.longitudeDelta))
        cameraBounds = MapCameraBounds(centerCoordinateBounds: region, minimumDistance: SFSUCampus.minCameraDistance,
                                       maximumDistance: maxDistance)
    }
}
