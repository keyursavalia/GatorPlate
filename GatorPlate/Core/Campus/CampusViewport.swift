import CoreGraphics
import Foundation

/// Keeps the visible north edge of the campus map at or below `SFSUCampus.northVisibleLimit`.
/// `MapCameraBounds` limits the camera *center*, so the allowed center has to follow the zoom: the further out,
/// the further south the center must stay. The pitch is always 0 (pan/zoom/rotate only), so for any heading the
/// furthest a visible point can be from the center is half the view diagonal.
/// Pure math: the map measures `metersPerPoint` at runtime and passes it in (no field-of-view constants).
nonisolated enum CampusViewport {
    /// Meters per degree of latitude (mean Earth radius).
    static let metersPerDegreeLatitude = 111_195.0

    /// How far past `limit` the visible north edge is, in meters (0 when inside). The north edge is the
    /// largest latitude of the 4 view corners.
    static func northExcess(cornerLatitudes: [Double], limit: Double) -> Double {
        guard let north = cornerLatitudes.max() else { return 0 }
        return max(0, (north - limit) * metersPerDegreeLatitude)
    }

    /// The center moved due south by `excessMeters`; longitude unchanged.
    static func correctedCenter(_ center: Coordinate, excessMeters: Double) -> Coordinate {
        Coordinate(latitude: center.latitude - excessMeters / metersPerDegreeLatitude, longitude: center.longitude)
    }

    /// Worst-case distance from the center to a visible point, for any heading: half the view diagonal.
    /// `metersPerPointPerMeter` is meters per screen point divided by the camera distance (it scales linearly).
    static func worstNorthExtent(distance: Double, metersPerPointPerMeter: Double, viewSize: CGSize) -> Double {
        distance * metersPerPointPerMeter * hypot(viewSize.width, viewSize.height) / 2
    }

    /// Highest center latitude at this distance whose worst-case north edge stays at `limit`, never above the
    /// static center limit (so zoomed in, the user can still center on UPN).
    static func adaptiveCenterNorthLimit(distance: Double, metersPerPointPerMeter: Double, viewSize: CGSize,
                                         limit: Double = SFSUCampus.northVisibleLimit,
                                         staticNorth: Double = SFSUCampus.cameraCenterNorthLatitude) -> Double {
        let extent = worstNorthExtent(distance: distance, metersPerPointPerMeter: metersPerPointPerMeter,
                                      viewSize: viewSize)
        return min(staticNorth, limit - extent / metersPerDegreeLatitude)
    }

    /// Largest camera distance at which the home view's worst-case north edge stays at `limit`
    /// (lower than the static maximum on wide views, e.g. landscape).
    static func adaptiveMaxDistance(metersPerPointPerMeter: Double, viewSize: CGSize,
                                    homeLatitude: Double = SFSUCampus.homeCoordinate.latitude,
                                    limit: Double = SFSUCampus.northVisibleLimit,
                                    staticMax: Double = SFSUCampus.maxCameraDistance) -> Double {
        let extentPerMeter = metersPerPointPerMeter * hypot(viewSize.width, viewSize.height) / 2
        guard extentPerMeter > 0 else { return staticMax }
        let room = (limit - homeLatitude) * metersPerDegreeLatitude
        return min(staticMax, max(SFSUCampus.minCameraDistance, room / extentPerMeter))
    }
}
