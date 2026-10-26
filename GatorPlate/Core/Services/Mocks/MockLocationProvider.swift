import Foundation
import Observation

#if DEBUG
@MainActor
@Observable
final class MockLocationProvider: LocationProviding {
    var authorization: LocationAuthorization
    var lastCoordinate: Coordinate?
    /// Where the simulated user stands once updates start.
    var simulatedCoordinate: Coordinate

    init(authorization: LocationAuthorization = .authorized(precise: true),
         simulatedCoordinate: Coordinate = SFSUCampus.homeCoordinate) {
        self.authorization = authorization
        self.simulatedCoordinate = simulatedCoordinate
    }

    /// What `requestAuthorization` answers when the status is `.notDetermined`.
    var answer: LocationAuthorization = .authorized(precise: true)

    func requestAuthorization() async -> LocationAuthorization {
        if authorization == .notDetermined { authorization = answer }
        return authorization
    }

    func requestTemporaryPreciseAccuracy() {
        if authorization.isAuthorized { authorization = .authorized(precise: true) }
    }

    func startUpdates() {
        if authorization.isAuthorized { lastCoordinate = simulatedCoordinate }
    }

    func stopUpdates() {}
}
#endif
