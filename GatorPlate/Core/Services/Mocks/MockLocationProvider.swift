import Foundation
import Observation

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

    func requestAuthorization() { authorization = .authorized(precise: true) }

    func requestTemporaryPreciseAccuracy() {
        if authorization.isAuthorized { authorization = .authorized(precise: true) }
    }

    func startUpdates() {
        if authorization.isAuthorized { lastCoordinate = simulatedCoordinate }
    }

    func stopUpdates() {}

    func currentCoordinate() async throws -> Coordinate {
        guard authorization.isAuthorized else { throw AppError.permissionDenied }
        return simulatedCoordinate
    }
}
