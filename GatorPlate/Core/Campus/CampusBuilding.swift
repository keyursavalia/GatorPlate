import Foundation

/// A well-known campus spot that posts can be pinned to.
nonisolated struct CampusBuilding: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let shortName: String
    let coordinate: Coordinate
}
