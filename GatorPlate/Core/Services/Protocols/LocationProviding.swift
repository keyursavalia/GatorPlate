import Foundation

nonisolated protocol LocationProviding: Sendable {
    func currentLocation() async throws -> Coordinate
}
