import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct FeedViewModelTests {
    private func makeModel(posts: [FoodPost]? = nil) -> (FeedViewModel, NavigationModel, PostsRepository) {
        let repository = PostsRepository(service: MockPostService(posts: []))
        if let posts { repository.apply(snapshot: posts) }
        let navigation = NavigationModel()
        let location = UserLocationModel(location: MockLocationProvider())
        return (FeedViewModel(repository: repository, location: location, navigation: navigation), navigation, repository)
    }

    @Test func showsASpinnerBeforeTheFirstSnapshot() {
        let (model, _, _) = makeModel()
        #expect(model.isLoading)
        #expect(!model.showsEmptyState)
    }

    @Test func showsTheEmptyStateOnlyAfterLoading() {
        let (model, _, _) = makeModel(posts: [])
        #expect(!model.isLoading)
        #expect(model.showsEmptyState)
    }

    @Test func listsActivePostsNewestFirst() {
        let now = Date()
        var older = SampleData.post(now: now, id: "older")
        older.createdAt = now.addingTimeInterval(-300)
        var newer = SampleData.post(now: now, id: "newer")
        newer.createdAt = now.addingTimeInterval(-10)
        let (model, _, _) = makeModel(posts: [older, newer])
        #expect(model.posts.map(\.id) == ["newer", "older"])
        #expect(!model.showsEmptyState)
    }

    @Test func tappingAPostOpensItOnTheMap() {
        let post = SampleData.post(id: "a")
        let (model, navigation, _) = makeModel(posts: [post])
        navigation.tab = .feed
        model.open(post)
        #expect(navigation.tab == .map)
        #expect(navigation.selectedPostID == "a")
    }

    @Test func distanceTextNeedsALocation() {
        let post = SampleData.post(id: "a")
        let (model, _, _) = makeModel(posts: [post])
        #expect(model.distanceText(to: post) == nil)
        model.location.apply(status: .authorizedFull)
        model.location.apply(location: SampleData.campusCoordinate)
        #expect(model.distanceText(to: post) != nil)
    }
}
