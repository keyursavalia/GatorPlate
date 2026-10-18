import Foundation

/// Foreground location for the map. Implementations are `@Observable` so views react to changes.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    /// Latest fix while updates run; nil before the first fix or without permission.
    var lastCoordinate: Coordinate? { get }

    /// Shows the system When-In-Use prompt and returns once the user decides (or the current status after a
    /// 60 s cap). The purpose string is the explanation; `FirstRunPermissions` decides when to call it.
    func requestAuthorization() async -> LocationAuthorization
    /// Asks for one-time precise location when the user chose approximate.
    func requestTemporaryPreciseAccuracy()
    /// Start when the map appears, stop when it disappears. Safe to call before permission is granted.
    func startUpdates()
    func stopUpdates()
    func currentCoordinate() async throws -> Coordinate
}

extension LocationProviding {
    var isOnCampus: Bool {
        lastCoordinate.map(SFSUCampus.contains) ?? false
    }

    /// Meters from the user's last fix, or nil when unknown.
    func distance(to coordinate: Coordinate) -> Double? {
        lastCoordinate?.distance(to: coordinate)
    }
}
