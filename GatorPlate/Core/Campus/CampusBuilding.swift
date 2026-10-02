import Foundation

nonisolated struct CampusBuilding: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let shortName: String
    let coordinate: Coordinate
}
