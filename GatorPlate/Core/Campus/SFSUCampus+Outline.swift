import Foundation

/// Campus outline for validating dropped pins. The `contains` rectangle also covers part of Stonestown
/// and a Font Blvd/Parkmerced sliver, so pins must also fall inside the real outline.
nonisolated extension SFSUCampus {
    /// OpenStreetMap campus outline (way 28965902, including University Park North), simplified with
    /// Douglas-Peucker at 6 m. Fetched 2026-10-07. Map data © OpenStreetMap contributors, ODbL.
    static let outline: [Coordinate] = [
        Coordinate(latitude: 37.72584, longitude: -122.47877),
        Coordinate(latitude: 37.72604, longitude: -122.47818),
        Coordinate(latitude: 37.72601, longitude: -122.47729),
        Coordinate(latitude: 37.72592, longitude: -122.47696),
        Coordinate(latitude: 37.72539, longitude: -122.47619),
        Coordinate(latitude: 37.72541, longitude: -122.47588),
        Coordinate(latitude: 37.72564, longitude: -122.47552),
        Coordinate(latitude: 37.72559, longitude: -122.47524),
        Coordinate(latitude: 37.72105, longitude: -122.47547),
        Coordinate(latitude: 37.72088, longitude: -122.47618),
        Coordinate(latitude: 37.72011, longitude: -122.47618),
        Coordinate(latitude: 37.72017, longitude: -122.47891),
        Coordinate(latitude: 37.71972, longitude: -122.47961),
        Coordinate(latitude: 37.71974, longitude: -122.47982),
        Coordinate(latitude: 37.72058, longitude: -122.48080),
        Coordinate(latitude: 37.72046, longitude: -122.48100),
        Coordinate(latitude: 37.72050, longitude: -122.48291),
        Coordinate(latitude: 37.72115, longitude: -122.48285),
        Coordinate(latitude: 37.72131, longitude: -122.48305),
        Coordinate(latitude: 37.72131, longitude: -122.48443),
        Coordinate(latitude: 37.72120, longitude: -122.48474),
        Coordinate(latitude: 37.72098, longitude: -122.48490),
        Coordinate(latitude: 37.72115, longitude: -122.48498),
        Coordinate(latitude: 37.72264, longitude: -122.48499),
        Coordinate(latitude: 37.72406, longitude: -122.48488),
        Coordinate(latitude: 37.72693, longitude: -122.48372),
        Coordinate(latitude: 37.72703, longitude: -122.48213),
        Coordinate(latitude: 37.72811, longitude: -122.48233),
        Coordinate(latitude: 37.72862, longitude: -122.48280),
        Coordinate(latitude: 37.72919, longitude: -122.48078),
        Coordinate(latitude: 37.72914, longitude: -122.47998),
        Coordinate(latitude: 37.72938, longitude: -122.47943),
        Coordinate(latitude: 37.72936, longitude: -122.47862),
        Coordinate(latitude: 37.72852, longitude: -122.47856),
        Coordinate(latitude: 37.72801, longitude: -122.47918),
        Coordinate(latitude: 37.72759, longitude: -122.47887),
        Coordinate(latitude: 37.72764, longitude: -122.47877),
        Coordinate(latitude: 37.72738, longitude: -122.47871),
    ]

    /// A dropped pin is valid inside the outline, or within `campusPinEdgeToleranceMeters` of it
    /// (sidewalks and building entrances sit on the edge).
    static func isValidPinLocation(_ coordinate: Coordinate) -> Bool {
        guard contains(coordinate) else { return false }
        return outlineContains(coordinate)
            || distanceToOutline(coordinate) <= AppConfig.campusPinEdgeToleranceMeters
    }

    /// Ray casting over the closed outline.
    static func outlineContains(_ coordinate: Coordinate) -> Bool {
        var isInside = false
        var previous = outline[outline.count - 1]
        for current in outline {
            if (current.latitude > coordinate.latitude) != (previous.latitude > coordinate.latitude) {
                let crossing = (previous.longitude - current.longitude)
                    * (coordinate.latitude - current.latitude) / (previous.latitude - current.latitude)
                    + current.longitude
                if coordinate.longitude < crossing { isInside.toggle() }
            }
            previous = current
        }
        return isInside
    }

    /// Meters to the nearest outline edge, using a flat projection (accurate at campus scale).
    static func distanceToOutline(_ coordinate: Coordinate) -> Double {
        let point = planar(coordinate)
        var nearest = Double.infinity
        var previous = planar(outline[outline.count - 1])
        for vertex in outline {
            let current = planar(vertex)
            nearest = min(nearest, distance(from: point, toSegment: previous, current))
            previous = current
        }
        return nearest
    }

    private static let metersPerDegreeLatitude = 111_320.0

    private static func planar(_ coordinate: Coordinate) -> (x: Double, y: Double) {
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(center.latitude * .pi / 180)
        return (coordinate.longitude * metersPerDegreeLongitude, coordinate.latitude * metersPerDegreeLatitude)
    }

    private static func distance(from point: (x: Double, y: Double),
                                 toSegment start: (x: Double, y: Double), _ end: (x: Double, y: Double)) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0 ? 0 : max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return hypot(point.x - start.x - t * dx, point.y - start.y - t * dy)
    }
}
