import Foundation

/// Where the food is: a catalog building, or a pin dropped inside campus (labeled by its nearest building).
nonisolated enum PostLocation: Hashable, Sendable {
    case building(CampusBuilding)
    case pin(Coordinate, nearest: CampusBuilding)

    var building: CampusBuilding {
        switch self {
        case .building(let building), .pin(_, let building): building
        }
    }

    var coordinate: Coordinate {
        switch self {
        case .building(let building): building.coordinate
        case .pin(let coordinate, _): coordinate
        }
    }

    /// Stored as `FoodPost.locationName`.
    var displayName: String {
        switch self {
        case .building(let building): building.name
        case .pin(_, let nearest): "Near \(nearest.name)"
        }
    }

    /// Used in the auto-title.
    var shortName: String {
        switch self {
        case .building(let building): building.shortName
        case .pin(_, let nearest): "near \(nearest.shortName)"
        }
    }
}
