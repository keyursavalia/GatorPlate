import Foundation

/// Verified campus spots. Coordinates are building centers from OpenStreetMap (Overpass query over the campus
/// bounding box, cross-checked with Nominatim for the Student Center, Library, Mashouf and the Village).
/// See `docs/PROGRESS.md` for the verification method. Do not add entries without verifying them.
nonisolated enum CampusBuildings {
    static let all: [CampusBuilding] = [
        CampusBuilding(
            id: "student-center", name: "Cesar Chavez Student Center", shortName: "Student Center",
            coordinate: Coordinate(latitude: 37.72235, longitude: -122.47863)),
        CampusBuilding(
            id: "library", name: "J. Paul Leonard Library", shortName: "Library",
            coordinate: Coordinate(latitude: 37.72139, longitude: -122.47813)),
        CampusBuilding(
            id: "student-services", name: "Student Services Building", shortName: "SSB",
            coordinate: Coordinate(latitude: 37.72339, longitude: -122.48080)),
        CampusBuilding(
            id: "mashouf", name: "Mashouf Wellness Center", shortName: "Mashouf",
            coordinate: Coordinate(latitude: 37.72291, longitude: -122.48426)),
        CampusBuilding(
            id: "science", name: "Science Building", shortName: "Science",
            coordinate: Coordinate(latitude: 37.72300, longitude: -122.47661)),
        CampusBuilding(
            id: "hensill", name: "Hensill Hall", shortName: "Hensill",
            coordinate: Coordinate(latitude: 37.72359, longitude: -122.47605)),
        CampusBuilding(
            id: "burk", name: "Burk Hall", shortName: "Burk",
            coordinate: Coordinate(latitude: 37.72290, longitude: -122.47961)),
        CampusBuilding(
            id: "fine-arts", name: "Fine Arts Building", shortName: "Fine Arts",
            coordinate: Coordinate(latitude: 37.72224, longitude: -122.47979)),
        CampusBuilding(
            id: "humanities", name: "Humanities Building", shortName: "Humanities",
            coordinate: Coordinate(latitude: 37.72242, longitude: -122.48109)),
        CampusBuilding(
            id: "business", name: "Business Building", shortName: "Business",
            coordinate: Coordinate(latitude: 37.72206, longitude: -122.47673)),
        CampusBuilding(
            id: "creative-arts", name: "Creative Arts Building", shortName: "Creative Arts",
            coordinate: Coordinate(latitude: 37.72152, longitude: -122.47974)),
        CampusBuilding(
            id: "village", name: "Village at Centennial Square", shortName: "The Village",
            coordinate: Coordinate(latitude: 37.72326, longitude: -122.48177)),
        CampusBuilding(
            id: "gymnasium", name: "Gymnasium", shortName: "Gym",
            coordinate: Coordinate(latitude: 37.72353, longitude: -122.47812)),
        CampusBuilding(
            id: "monarca", name: "Monarca Dining Hall", shortName: "Monarca",
            coordinate: Coordinate(latitude: 37.72381, longitude: -122.48299)),
    ]

    static func building(id: String) -> CampusBuilding? {
        all.first { $0.id == id }
    }
}
