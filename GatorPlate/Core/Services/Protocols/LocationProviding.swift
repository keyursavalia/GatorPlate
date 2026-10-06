import Foundation

@MainActor
protocol LocationProviding {
    var isAuthorized: Bool { get }
    func requestAuthorization()
    func currentCoordinate() async throws -> Coordinate
}
