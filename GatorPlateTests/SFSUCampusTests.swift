import Testing
@testable import GatorPlate

struct SFSUCampusTests {
    @Test func centerIsInside() {
        #expect(SFSUCampus.contains(SFSUCampus.center))
    }

    @Test func fartherAwayPlacesAreOutside() {
        let applePark = Coordinate(latitude: 37.3349, longitude: -122.0090)
        let downtown = Coordinate(latitude: 37.7879, longitude: -122.4074)
        let stonestown = Coordinate(latitude: 37.7280, longitude: -122.4772)
        #expect(!SFSUCampus.contains(applePark))
        #expect(!SFSUCampus.contains(downtown))
        #expect(!SFSUCampus.contains(stonestown))
    }

    @Test func edgesAreInclusive() {
        let corners = [
            Coordinate(latitude: SFSUCampus.minLatitude, longitude: SFSUCampus.minLongitude),
            Coordinate(latitude: SFSUCampus.maxLatitude, longitude: SFSUCampus.maxLongitude),
            Coordinate(latitude: SFSUCampus.minLatitude, longitude: SFSUCampus.maxLongitude),
            Coordinate(latitude: SFSUCampus.maxLatitude, longitude: SFSUCampus.minLongitude),
        ]
        #expect(corners.allSatisfy(SFSUCampus.contains))
    }

    @Test func justPastEachEdgeIsOutside() {
        let step = 0.0001
        let c = SFSUCampus.center
        #expect(!SFSUCampus.contains(Coordinate(latitude: SFSUCampus.maxLatitude + step, longitude: c.longitude)))
        #expect(!SFSUCampus.contains(Coordinate(latitude: SFSUCampus.minLatitude - step, longitude: c.longitude)))
        #expect(!SFSUCampus.contains(Coordinate(latitude: c.latitude, longitude: SFSUCampus.maxLongitude + step)))
        #expect(!SFSUCampus.contains(Coordinate(latitude: c.latitude, longitude: SFSUCampus.minLongitude - step)))
    }

    @Test func zoomRangeIsSane() {
        #expect(SFSUCampus.minimumCameraDistance < SFSUCampus.overviewCameraDistance)
        #expect(SFSUCampus.overviewCameraDistance <= SFSUCampus.maximumCameraDistance)
    }
}

struct DistanceTests {
    @Test func oneThousandthDegreeOfLatitudeIsAbout111Meters() {
        let a = Coordinate(latitude: 37.700, longitude: -122.4)
        let b = Coordinate(latitude: 37.701, longitude: -122.4)
        #expect(abs(a.distance(to: b) - 111.2) < 1.0)
    }

    @Test func distanceIsSymmetricAndZeroToSelf() throws {
        let library = try #require(CampusBuildings.building(id: "library")).coordinate
        let mashouf = try #require(CampusBuildings.building(id: "mashouf")).coordinate
        #expect(library.distance(to: library) == 0)
        #expect(abs(library.distance(to: mashouf) - mashouf.distance(to: library)) < 0.001)
    }

    @Test func libraryToMashoufIsAbout565Meters() throws {
        let library = try #require(CampusBuildings.building(id: "library")).coordinate
        let mashouf = try #require(CampusBuildings.building(id: "mashouf")).coordinate
        #expect(abs(library.distance(to: mashouf) - 565) < 20)
    }
}
