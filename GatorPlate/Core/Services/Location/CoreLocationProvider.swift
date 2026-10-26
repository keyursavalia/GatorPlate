import CoreLocation
import Observation
import OSLog

/// Live location via CoreLocation. Never prompts on its own: `FirstRunPermissions` asks on the first Map appearance.
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
    /// Waiting for the user to answer the system prompt.
    @ObservationIgnored private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []

    /// After this long the request returns the current status, even if the alert is still up.
    private static let authorizationWaitCap: Duration = .seconds(60)

    override init() {
        super.init()
        manager.delegate = self
        refreshAuthorization()
    }

    func requestAuthorization() async -> LocationAuthorization {
        guard authorization == .notDetermined else { return authorization }
        let cap = Task { [weak self] in
            try? await Task.sleep(for: Self.authorizationWaitCap)
            guard !Task.isCancelled else { return }
            self?.resumeAuthorizationWaiters()
        }
        defer { cap.cancel() }
        return await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    private func resumeAuthorizationWaiters() {
        let waiters = authorizationWaiters
        authorizationWaiters = []
        for waiter in waiters { waiter.resume(returning: authorization) }
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
        if authorization != .notDetermined { resumeAuthorizationWaiters() }
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
