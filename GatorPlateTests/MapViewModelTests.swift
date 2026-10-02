import Foundation
import MapKit
import Testing
@testable import GatorPlate

@MainActor
struct MapViewModelTests {
    private let onCampus = Coordinate(latitude: 37.7222, longitude: -122.4786)
    private let offCampus = Coordinate(latitude: 37.3349, longitude: -122.0090)

    private func makeModel(
        posts: [FoodPost] = SampleData.mapPosts(),
        routing: any RoutingService = MockRoutingService()
    ) -> MapViewModel {
        PreviewSupport.mapViewModel(posts: posts, routing: routing)
    }

    // MARK: Banner priority

    @Test func notDeterminedShowsThePrePrompt() {
        let model = makeModel()
        model.location.apply(status: .notDetermined)
        #expect(model.banner == .permissionPrompt)
    }

    @Test func deniedShowsSettingsBanner() {
        let model = makeModel()
        model.location.apply(status: .denied)
        #expect(model.banner == .locationDenied)
        #expect(model.location.userLocation == nil)
    }

    @Test func reducedAccuracyShowsAccuracyBanner() {
        let model = makeModel()
        model.location.apply(status: .authorizedReduced)
        model.location.apply(location: onCampus)
        #expect(model.banner == .reducedAccuracy)
    }

    @Test func fullAccuracyOnCampusShowsNoBanner() {
        let model = makeModel()
        model.location.apply(status: .authorizedFull)
        model.location.apply(location: onCampus)
        #expect(model.banner == nil)
        #expect(model.location.isOnCampus)
    }

    @Test func offCampusShowsBanner() {
        let model = makeModel()
        model.location.apply(status: .authorizedFull)
        model.location.apply(location: offCampus)
        #expect(model.banner == .offCampus)
        #expect(!model.location.isOnCampus)
    }

    // MARK: Posts and labels

    @Test func accessibilityLabelNamesTitleTimeAndDistance() {
        let now = Date()
        var post = SampleData.mapPosts(now: now)[0]
        post.expiresAt = now.addingTimeInterval(24 * 60)
        let model = makeModel(posts: [post])
        #expect(model.accessibilityLabel(for: post, now: now).hasPrefix("Free food: \(post.title), 24 minutes left"))
        #expect(model.accessibilityLabel(for: post, now: now).contains("away"))

        model.location.apply(status: .denied)
        #expect(model.accessibilityLabel(for: post, now: now) == "Free food: \(post.title), 24 minutes left")
    }

    @Test func expiredPostsAreNotShown() {
        var expired = SampleData.post(id: "old")
        expired.expiresAt = Date().addingTimeInterval(-60)
        let model = makeModel(posts: [expired])
        #expect(model.activePosts.isEmpty)
    }

    @Test func selectedPostIsNilWhenItIsNotActive() {
        let model = makeModel()
        model.selectedPostID = "does-not-exist"
        #expect(model.selectedPost == nil)
        model.selectedPostID = "map-1"
        #expect(model.selectedPost?.id == "map-1")
    }

    // MARK: Recenter

    @Test func recenterOnCampusTargetsTheUser() {
        let model = makeModel()
        model.location.apply(status: .authorizedFull)
        model.location.apply(location: onCampus)
        model.recenter()
        #expect(model.cameraPosition.camera?.centerCoordinate.latitude == onCampus.latitude)
        #expect(model.cameraPosition.camera?.centerCoordinate.longitude == onCampus.longitude)
    }

    @Test func recenterOffCampusTargetsCampusCenter() {
        let model = makeModel()
        model.location.apply(status: .authorizedFull)
        model.location.apply(location: offCampus)
        model.recenter()
        #expect(model.cameraPosition.camera?.centerCoordinate.latitude == SFSUCampus.center.latitude)
        #expect(model.cameraPosition.camera?.centerCoordinate.longitude == SFSUCampus.center.longitude)
    }

    // MARK: Routes and selection

    @Test func directionsRouteIsShownOnlyForTheSelectedPost() async {
        let model = makeModel()
        model.selectedPostID = "map-1"
        model.startDirections()
        await model.route.waitForCompletion()
        #expect(model.visibleRoute?.postID == "map-1")

        model.selectedPostID = "map-2"
        #expect(model.routeState == .idle)
        #expect(model.visibleRoute == nil)
    }

    @Test func changingTheSelectionEndsTheRoute() async {
        let model = makeModel()
        model.selectedPostID = "map-1"
        model.startDirections()
        await model.route.waitForCompletion()

        model.selectedPostID = "map-2"
        model.selectionChanged()
        #expect(model.route.state == .idle)
    }

    @Test func dismissingTheCardEndsTheRoute() async {
        let model = makeModel()
        model.selectedPostID = "map-1"
        model.startDirections()
        await model.route.waitForCompletion()

        model.selectedPostID = nil
        model.selectionChanged()
        #expect(model.route.state == .idle)
    }

    @Test func endRouteRestoresTheCamera() async {
        let model = makeModel()
        model.location.apply(status: .authorizedFull)
        model.location.apply(location: onCampus)
        model.selectedPostID = "map-1"
        model.startDirections()
        await model.route.waitForCompletion()
        model.fitCameraToRoute()
        #expect(model.cameraPosition.rect != nil)

        model.endRoute()
        #expect(model.route.state == .idle)
        #expect(model.cameraPosition.rect == nil)
        // On campus with a fix: back to the user, like Recenter.
        let user = model.location.userLocation
        #expect(model.cameraPosition.camera?.centerCoordinate.latitude == user?.latitude)
    }

    @Test func aPostThatGoesAwayEndsItsRouteAndClearsTheSelection() async {
        let model = makeModel()
        model.selectedPostID = "map-1"
        model.startDirections()
        await model.route.waitForCompletion()

        model.repository.apply(snapshot: SampleData.mapPosts().filter { $0.id != "map-1" })
        model.postsChanged()
        #expect(model.selectedPostID == nil)
        #expect(model.route.state == .idle)
    }

    @Test func openInAppleMapsPassesTheSelectedPost() {
        let routing = MockRoutingService()
        let model = makeModel(routing: routing)
        #expect(!model.openInAppleMaps())

        model.selectedPostID = "map-1"
        #expect(model.openInAppleMaps())
        let opened = routing.opened
        #expect(opened.count == 1)
        #expect(opened.first?.coordinate.latitude == model.selectedPost?.latitude)
    }

    @Test func routeCameraRectContainsTheRoute() throws {
        let coordinates = [onCampus, Coordinate(latitude: 37.7231, longitude: -122.4775)]
        let rect = try #require(RouteCamera.rect(for: coordinates))
        for coordinate in coordinates {
            #expect(rect.contains(MKMapPoint(coordinate.clCoordinate)))
        }
        #expect(RouteCamera.rect(for: []) == nil)
    }
}
