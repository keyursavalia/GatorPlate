import Foundation

/// Verified coordinates. Source per entry: Apple MKLocalSearch when its exact-name result was within
/// 60 m of the OpenStreetMap footprint, otherwise the OSM footprint centroid (marked "OSM").
/// Never add a building without verifying it the same way (see docs/PROGRESS.md).
nonisolated extension CampusBuilding {
    static let all: [CampusBuilding] = [
        CampusBuilding(id: "chavez", name: "Cesar Chavez Student Center", shortName: "Chavez Center",
                       coordinate: Coordinate(latitude: 37.722191, longitude: -122.478631)),
        CampusBuilding(id: "library", name: "J. Paul Leonard Library", shortName: "Library",
                       coordinate: Coordinate(latitude: 37.721213, longitude: -122.478021)),
        // OSM
        CampusBuilding(id: "ssb", name: "Student Services Building", shortName: "SSB",
                       coordinate: Coordinate(latitude: 37.723390, longitude: -122.480804)),
        CampusBuilding(id: "mashouf", name: "Mashouf Wellness Center", shortName: "Mashouf",
                       coordinate: Coordinate(latitude: 37.722845, longitude: -122.484423)),
        // OSM
        CampusBuilding(id: "science", name: "Science Building", shortName: "Science",
                       coordinate: Coordinate(latitude: 37.722997, longitude: -122.476612)),
        CampusBuilding(id: "hensill", name: "Hensill Hall", shortName: "Hensill",
                       coordinate: Coordinate(latitude: 37.723520, longitude: -122.476140)),
        CampusBuilding(id: "burk", name: "Burk Hall", shortName: "Burk",
                       coordinate: Coordinate(latitude: 37.722940, longitude: -122.479357)),
        // OSM
        CampusBuilding(id: "fineArts", name: "Fine Arts Building", shortName: "Fine Arts",
                       coordinate: Coordinate(latitude: 37.722242, longitude: -122.479792)),
        CampusBuilding(id: "humanities", name: "Humanities Building", shortName: "Humanities",
                       coordinate: Coordinate(latitude: 37.722132, longitude: -122.481433)),
        CampusBuilding(id: "business", name: "Business Building", shortName: "Business",
                       coordinate: Coordinate(latitude: 37.722067, longitude: -122.476736)),
        // OSM
        CampusBuilding(id: "creativeArts", name: "Creative Arts Building", shortName: "Creative Arts",
                       coordinate: Coordinate(latitude: 37.721518, longitude: -122.479739)),
        CampusBuilding(id: "village", name: "Village at Centennial Square", shortName: "The Village",
                       coordinate: Coordinate(latitude: 37.723521, longitude: -122.482313)),
        CampusBuilding(id: "gym", name: "Gymnasium", shortName: "Gym",
                       coordinate: Coordinate(latitude: 37.723640, longitude: -122.478268)),
        CampusBuilding(id: "thornton", name: "Thornton Hall", shortName: "Thornton",
                       coordinate: Coordinate(latitude: 37.724008, longitude: -122.476880)),
        CampusBuilding(id: "hss", name: "Health & Social Sciences", shortName: "HSS",
                       coordinate: Coordinate(latitude: 37.721771, longitude: -122.476116)),
    ]

    static func byId(_ id: String) -> CampusBuilding? {
        all.first { $0.id == id }
    }
}
