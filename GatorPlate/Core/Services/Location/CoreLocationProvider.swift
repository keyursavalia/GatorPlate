import CoreLocation
import Observation
import OSLog

/// Live location via CoreLocation. Never prompts on its own: the map asks only after its pre-prompt.
@MainActor
@Observable
final class CoreLocationProvider: NSObject, LocationProviding {
    private(set) var authorization: LocationAuthorization = .notDetermined
    private(set) var lastCoordinate: Coordinate?

    @ObservationIgnored private let manager = CLLocationManager()
    /// Held while updating; creating one before permission is granted would show the system prompt.
    @ObservationIgnored private var session: CLServiceSession?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var wantsUpdates = false

    override init() {
        super.init()
        manager.delegate = self
        refreshAuthorization()
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestTemporaryPreciseAccuracy() {
        // The delegate reports the new accuracy; the completion only logs failures.
        manager.requestTemporaryFullAccuracyAuthorization(
            withPurposeKey: AppConfig.preciseLocationPurposeKey
        ) { @Sendable error in
            if let error {
                Logger.services.error("Temporary full accuracy failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func startUpdates() {
        wantsUpdates = true
        beginUpdatesIfPossible()
    }

    func stopUpdates() {
        wantsUpdates = false
        endUpdates()
    }

    func currentCoordinate() async throws -> Coordinate {
        if let lastCoordinate { return lastCoordinate }
        guard authorization.isAuthorized else { throw AppError.permissionDenied }
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location { return Coordinate(location.coordinate) }
            if update.authorizationDenied || update.authorizationRestricted { throw AppError.permissionDenied }
        }
        throw AppError.unknown
    }

    private func beginUpdatesIfPossible() {
        guard wantsUpdates, authorization.isAuthorized, updatesTask == nil else { return }
        session = CLServiceSession(authorization: .whenInUse)
        updatesTask = Task { [weak self] in
            do {
                // Pedestrian navigation profile: highest accuracy for walking around campus.
                for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    guard let self else { return }
                    if let location = update.location, location.horizontalAccuracy >= 0 {
                        self.lastCoordinate = Coordinate(location.coordinate)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                Logger.services.error("Location updates ended: \(error.localizedDescription, privacy: .public)")
            }
        }
        Logger.services.info("Location updates started")
    }

    private func endUpdates() {
        guard updatesTask != nil || session != nil else { return }
        updatesTask?.cancel()
        updatesTask = nil
        session?.invalidate()
        session = nil
        Logger.services.info("Location updates stopped")
    }

    private func refreshAuthorization() {
        authorization = switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedWhenInUse, .authorizedAlways:
            .authorized(precise: manager.accuracyAuthorization == .fullAccuracy)
        @unknown default: .denied
        }
        if authorization.isAuthorized {
            beginUpdatesIfPossible()
        } else {
            endUpdates()
            lastCoordinate = nil
        }
    }
}

extension CoreLocationProvider: CLLocationManagerDelegate {
    /// The manager is created on the main thread, so CoreLocation calls back on the main thread.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            refreshAuthorization()
        }
    }
}
