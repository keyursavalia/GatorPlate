import Foundation

/// Why an in-app walking route can't be shown. "Open in Apple Maps" stays available for every case.
nonisolated enum RouteFailure: Error, Equatable, Sendable {
    /// Location permission not granted (not asked, denied or restricted).
    case locationOff
    /// Permission granted but no fix arrived in time.
    case locationUnavailable
    /// The user is outside the campus map, so the route can't be drawn inside it.
    case offCampus
    case noRoute
    case network
    case throttled
    /// The request was replaced or ended; never shown.
    case cancelled
    case unknown
}
