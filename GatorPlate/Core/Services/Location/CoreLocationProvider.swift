import Foundation
import OSLog

/// Live location via CoreLocation. Stub until Sprint 02.
@MainActor
final class CoreLocationProvider: LocationProviding {
    var isAuthorized: Bool { false }

    func requestAuthorization() {
        Logger.services.notice("CoreLocationProvider.requestAuthorization not implemented")
    }

    func currentCoordinate() async throws -> Coordinate {
        throw AppError.permissionDenied
    }
}
