import Foundation

@MainActor
final class MockLocationProvider: LocationProviding {
    var isAuthorized = true
    var coordinate = Coordinate(latitude: 37.7219, longitude: -122.4782)

    func requestAuthorization() { isAuthorized = true }

    func currentCoordinate() async throws -> Coordinate {
        guard isAuthorized else { throw AppError.permissionDenied }
        return coordinate
    }
}
