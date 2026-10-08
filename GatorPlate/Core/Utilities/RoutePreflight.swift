import Foundation

/// Checks before asking MapKit for a walking route. Pure, so every branch is easy to verify.
nonisolated enum RoutePreflight {
    static func check(authorization: LocationAuthorization) -> RouteFailure? {
        authorization.isAuthorized ? nil : .locationOff
    }

    /// The route is drawn inside the campus-locked map, so it must start on campus.
    static func check(origin: Coordinate?) -> RouteFailure? {
        guard let origin else { return .locationUnavailable }
        return SFSUCampus.contains(origin) ? nil : .offCampus
    }
}
