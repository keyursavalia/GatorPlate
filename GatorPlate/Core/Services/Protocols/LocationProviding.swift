import Foundation

nonisolated enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    /// Denied by the user or restricted on the device. Both are fixed in Settings.
    case denied
    case authorized
}

nonisolated enum LocationAccuracy: Equatable, Sendable {
    case full
    case reduced
}

nonisolated struct LocationStatus: Equatable, Sendable {
    var authorization: LocationAuthorization
    var accuracy: LocationAccuracy

    static let notDetermined = LocationStatus(authorization: .notDetermined, accuracy: .full)
    static let denied = LocationStatus(authorization: .denied, accuracy: .full)
    static let authorizedFull = LocationStatus(authorization: .authorized, accuracy: .full)
    static let authorizedReduced = LocationStatus(authorization: .authorized, accuracy: .reduced)
}

nonisolated protocol LocationProviding: Sendable {
    /// One fix. Throws `AppError.permissionDenied` if not authorized; never triggers the permission prompt.
    func currentLocation() async throws -> Coordinate

    /// Emits the current status immediately, then every change. Ends when the consuming task is cancelled.
    func statusUpdates() async -> AsyncStream<LocationStatus>

    /// Live fixes at best accuracy. Only call once authorized. Ends (and stops the hardware) when the consuming task is cancelled.
    func locationUpdates() async -> AsyncStream<Coordinate>

    /// Shows the system When-In-Use prompt. Call only after our own explanation.
    func requestWhenInUseAuthorization() async

    /// Asks for one-time full accuracy (purpose key `FoodNearby`).
    func requestTemporaryFullAccuracy() async
}
