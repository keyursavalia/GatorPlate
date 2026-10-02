import Testing
@testable import GatorPlate

@MainActor
struct UserLocationModelTests {
    private let onCampus = Coordinate(latitude: 37.7222, longitude: -122.4786)

    @Test func runAppliesStatusAndLocation() async {
        let model = UserLocationModel(location: MockLocationProvider(status: .authorizedFull, coordinate: onCampus))
        let task = Task { await model.run() }
        let arrived = await waitUntil { model.userLocation != nil }
        task.cancel()
        #expect(arrived)
        #expect(model.userLocation == onCampus)
    }

    @Test func runDoesNotTrackWhenNotAuthorized() async {
        let model = UserLocationModel(location: MockLocationProvider(status: .denied, coordinate: onCampus))
        let task = Task { await model.run() }
        _ = await waitUntil { model.status == .denied }
        task.cancel()
        #expect(model.userLocation == nil)
    }

    @Test func distanceIsNilWithoutALocation() {
        let model = UserLocationModel(location: MockLocationProvider())
        #expect(model.distance(to: SampleData.mapPosts()[0]) == nil)
        #expect(model.distanceText(to: SampleData.mapPosts()[0]) == nil)
    }

    @Test func distanceIsMetersToThePost() {
        let model = UserLocationModel(location: MockLocationProvider())
        model.apply(status: .authorizedFull)
        model.apply(location: onCampus)
        let post = SampleData.mapPosts()[0]
        let expected = onCampus.distance(to: Coordinate(latitude: post.latitude, longitude: post.longitude))
        #expect(model.distance(to: post) == expected)
        #expect(model.distanceText(to: post) != nil)
    }

    @Test func losingPermissionClearsTheLocation() {
        let model = UserLocationModel(location: MockLocationProvider())
        model.apply(status: .authorizedFull)
        model.apply(location: onCampus)
        model.apply(status: .denied)
        #expect(model.userLocation == nil)
    }
}
