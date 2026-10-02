import Foundation
import MapKit
import Testing
@testable import GatorPlate

@MainActor
struct MapViewModelTests {
    private let onCampus = Coordinate(latitude: 37.7222, longitude: -122.4786)
    private let offCampus = Coordinate(latitude: 37.3349, longitude: -122.0090)

    private func makeModel() -> MapViewModel {
        MapViewModel(location: MockLocationProvider())
    }

    // MARK: Banner priority

    @Test func notDeterminedShowsThePrePrompt() {
        let model = makeModel()
        model.apply(status: .notDetermined)
        #expect(model.banner == .permissionPrompt)
    }

    @Test func deniedShowsSettingsBanner() {
        let model = makeModel()
        model.apply(status: .denied)
        #expect(model.banner == .locationDenied)
        #expect(model.userLocation == nil)
    }

    @Test func reducedAccuracyShowsAccuracyBanner() {
        let model = makeModel()
        model.apply(status: .authorizedReduced)
        model.apply(location: onCampus)
        #expect(model.banner == .reducedAccuracy)
    }

    @Test func fullAccuracyOnCampusShowsNoBanner() {
        let model = makeModel()
        model.apply(status: .authorizedFull)
        model.apply(location: onCampus)
        #expect(model.banner == nil)
        #expect(model.isOnCampus)
    }

    @Test func offCampusShowsBanner() {
        let model = makeModel()
        model.apply(status: .authorizedFull)
        model.apply(location: offCampus)
        #expect(model.banner == .offCampus)
        #expect(!model.isOnCampus)
    }

    @Test func authorizedWithoutAFixYetShowsNoBanner() {
        let model = makeModel()
        model.apply(status: .authorizedFull)
        #expect(model.banner == nil)
    }

    // MARK: Streams

    @Test func runAppliesStatusAndLocation() async {
        let model = MapViewModel(location: MockLocationProvider(status: .authorizedFull, coordinate: onCampus))
        let task = Task { await model.run() }
        let arrived = await waitUntil { model.userLocation != nil }
        task.cancel()
        #expect(arrived)
        #expect(model.userLocation == onCampus)
    }

    @Test func runDoesNotTrackWhenNotAuthorized() async {
        let model = MapViewModel(location: MockLocationProvider(status: .denied, coordinate: onCampus))
        let task = Task { await model.run() }
        _ = await waitUntil { model.status == .denied }
        task.cancel()
        #expect(model.userLocation == nil)
    }

    // MARK: Posts and labels

    @Test func distanceIsNilWithoutALocation() {
        let model = makeModel()
        let post = SampleData.mapPosts()[0]
        #expect(model.distance(to: post) == nil)
    }

    @Test func accessibilityLabelNamesTitleTimeAndDistance() {
        let model = makeModel()
        let now = Date()
        var post = SampleData.mapPosts(now: now)[0]
        post.expiresAt = now.addingTimeInterval(24 * 60)
        #expect(model.accessibilityLabel(for: post, now: now) == "Free food: \(post.title), 24 minutes left")

        model.apply(status: .authorizedFull)
        model.apply(location: onCampus)
        #expect(model.accessibilityLabel(for: post, now: now).contains("away"))
    }

    @Test func expiredPostsAreNotShown() {
        var expired = SampleData.post(id: "old")
        expired.expiresAt = Date().addingTimeInterval(-60)
        let model = MapViewModel(location: MockLocationProvider(), posts: [expired])
        #expect(model.activePosts.isEmpty)
    }

    // MARK: Recenter

    @Test func recenterOnCampusTargetsTheUser() {
        let model = makeModel()
        model.apply(status: .authorizedFull)
        model.apply(location: onCampus)
        model.recenter()
        #expect(model.cameraPosition.camera?.centerCoordinate.latitude == onCampus.latitude)
        #expect(model.cameraPosition.camera?.centerCoordinate.longitude == onCampus.longitude)
    }

    @Test func recenterOffCampusTargetsCampusCenter() {
        let model = makeModel()
        model.apply(status: .authorizedFull)
        model.apply(location: offCampus)
        model.recenter()
        #expect(model.cameraPosition.camera?.centerCoordinate.latitude == SFSUCampus.center.latitude)
        #expect(model.cameraPosition.camera?.centerCoordinate.longitude == SFSUCampus.center.longitude)
    }
}
