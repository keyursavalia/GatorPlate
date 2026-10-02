import CoreLocation
import OSLog

/// CoreLocation-backed provider. Nothing starts at launch: updates run only while a consumer iterates
/// `locationUpdates()`, and the permission prompt appears only from `requestWhenInUseAuthorization()`.
@MainActor
final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private static let fullAccuracyPurposeKey = "FoodNearby"

    private let manager = CLLocationManager()
    private var statusContinuations: [UUID: AsyncStream<LocationStatus>.Continuation] = [:]

    override init() {
        super.init()
        manager.delegate = self
    }

    // MARK: LocationProviding

    func currentLocation() async throws -> Coordinate {
        guard currentStatus().authorization == .authorized else { throw AppError.permissionDenied }
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied { throw AppError.permissionDenied }
            if let location = update.location { return Coordinate(location.coordinate) }
        }
        throw AppError.unknown
    }

    func statusUpdates() async -> AsyncStream<LocationStatus> {
        AsyncStream { continuation in
            let id = UUID()
            statusContinuations[id] = continuation
            continuation.yield(currentStatus())
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.statusContinuations[id] = nil }
            }
        }
    }

    func locationUpdates() async -> AsyncStream<Coordinate> {
        AsyncStream { continuation in
            let task = Task {
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location {
                            continuation.yield(Coordinate(location.coordinate))
                        }
                    }
                } catch {
                    Logger.app.error("Live location updates ended: \(error.localizedDescription, privacy: .public)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func requestWhenInUseAuthorization() async {
        manager.requestWhenInUseAuthorization()
    }

    func requestTemporaryFullAccuracy() async {
        do {
            try await manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: Self.fullAccuracyPurposeKey)
        } catch {
            Logger.app.error("Temporary full accuracy request failed: \(error.localizedDescription, privacy: .public)")
        }
        publishStatus()
    }

    // MARK: CLLocationManagerDelegate

    /// Delivered on the main thread because the manager is created there.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated { publishStatus() }
    }

    // MARK: Status

    private func currentStatus() -> LocationStatus {
        let authorization: LocationAuthorization = switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
        let accuracy: LocationAccuracy = manager.accuracyAuthorization == .reducedAccuracy ? .reduced : .full
        return LocationStatus(authorization: authorization, accuracy: accuracy)
    }

    private func publishStatus() {
        let status = currentStatus()
        for continuation in statusContinuations.values {
            continuation.yield(status)
        }
    }
}
