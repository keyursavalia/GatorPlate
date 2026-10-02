import Testing
@testable import GatorPlate

struct CampusBuildingsTests {
    @Test func catalogHasTheExpectedSpots() {
        #expect(CampusBuildings.all.count >= 10)
    }

    @Test func everyBuildingIsInsideCampusBounds() {
        for building in CampusBuildings.all {
            #expect(SFSUCampus.contains(building.coordinate), "\(building.name) is outside the campus bounds")
        }
    }

    @Test func buildingIDsAreUnique() {
        let ids = CampusBuildings.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func namesAreFilledIn() {
        #expect(CampusBuildings.all.allSatisfy { !$0.name.isEmpty && !$0.shortName.isEmpty })
    }

    @Test func lookupByID() {
        #expect(CampusBuildings.building(id: "library")?.name == "J. Paul Leonard Library")
        #expect(CampusBuildings.building(id: "nope") == nil)
    }

    @Test func mockMapPostsSitAtCatalogBuildings() {
        let posts = SampleData.mapPosts()
        #expect(!posts.isEmpty)
        for post in posts {
            #expect(CampusBuildings.building(id: post.buildingId) != nil)
            #expect(SFSUCampus.contains(Coordinate(latitude: post.latitude, longitude: post.longitude)))
            #expect(post.isActive())
        }
    }
}
