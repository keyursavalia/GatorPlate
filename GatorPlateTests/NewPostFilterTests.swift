import Foundation
import Testing
@testable import GatorPlate

struct NewPostFilterTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func post(
        id: String,
        author: String = "other",
        createdAt: Date? = nil,
        expiresIn: TimeInterval = 1800,
        status: PostStatus = .active
    ) -> FoodPost {
        var post = SampleData.post(now: start, id: id)
        post.authorUid = author
        post.createdAt = createdAt ?? start.addingTimeInterval(60)
        post.expiresAt = start.addingTimeInterval(expiresIn)
        post.status = status
        return post
    }

    private func seededFilter() -> NewPostFilter {
        var filter = NewPostFilter(currentUserID: "me", sessionStart: start)
        filter.seed(with: [])
        return filter
    }

    @Test func alertsForANewPostFromSomeoneElse() {
        var filter = seededFilter()
        #expect(filter.newPosts(in: [post(id: "a")], now: start).map(\.id) == ["a"])
    }

    @Test func neverAlertsBeforeTheFirstSnapshotSeeds() {
        var filter = NewPostFilter(currentUserID: "me", sessionStart: start)
        #expect(filter.newPosts(in: [post(id: "a")], now: start).isEmpty)
    }

    @Test func ignoresMyOwnPosts() {
        var filter = seededFilter()
        #expect(filter.newPosts(in: [post(id: "a", author: "me")], now: start).isEmpty)
    }

    @Test func ignoresPostsCreatedBeforeTheSessionStarted() {
        var filter = seededFilter()
        let old = post(id: "a", createdAt: start.addingTimeInterval(-10))
        #expect(filter.newPosts(in: [old], now: start).isEmpty)
    }

    @Test func ignoresExpiredAndGonePosts() {
        var filter = seededFilter()
        let expired = post(id: "a", expiresIn: 30)
        let gone = post(id: "b", status: .gone)
        #expect(filter.newPosts(in: [expired, gone], now: start.addingTimeInterval(120)).isEmpty)
    }

    @Test func seededPostsNeverAlertEvenWhenTheirClockIsAhead() {
        var filter = NewPostFilter(currentUserID: "me", sessionStart: start)
        let existing = post(id: "a", createdAt: start.addingTimeInterval(500))
        filter.seed(with: [existing])
        #expect(filter.newPosts(in: [existing], now: start).isEmpty)
    }

    @Test func eachPostAlertsOnlyOnce() {
        var filter = seededFilter()
        let posts = [post(id: "a")]
        #expect(filter.newPosts(in: posts, now: start).count == 1)
        #expect(filter.newPosts(in: posts, now: start).isEmpty)
    }

    @Test func secondSeedIsIgnored() {
        var filter = NewPostFilter(currentUserID: "me", sessionStart: start)
        filter.seed(with: [])
        filter.seed(with: [post(id: "a")])
        #expect(filter.newPosts(in: [post(id: "a")], now: start).count == 1)
    }

    @Test func returnsNewPostsOldestFirst() {
        var filter = seededFilter()
        let later = post(id: "later", createdAt: start.addingTimeInterval(120))
        let earlier = post(id: "earlier", createdAt: start.addingTimeInterval(60))
        #expect(filter.newPosts(in: [later, earlier], now: start).map(\.id) == ["earlier", "later"])
    }
}

struct AlertContentFormatterTests {
    @Test func formatsTitleAndBuilding() {
        var post = SampleData.post()
        post.title = "Pad Thai"
        post.locationName = "Student Center"
        let content = AlertContentFormatter.content(for: post)
        #expect(content.title == "Free food: Pad Thai")
        #expect(content.body == "Student Center")
        #expect(content.postID == post.id)
        #expect(AlertContentFormatter.bannerMessage(for: content) == "Free food: Pad Thai, Student Center")
    }

    @Test func clipsVeryLongTitles() {
        var post = SampleData.post()
        post.title = String(repeating: "x", count: 300)
        let content = AlertContentFormatter.content(for: post)
        #expect(content.title.count <= AlertContentFormatter.titlePrefix.count + 2 + AlertContentFormatter.maxTitleLength)
        #expect(content.title.hasSuffix("…"))
    }

    @Test func blankTitleFallsBack() {
        var post = SampleData.post()
        post.title = "   "
        #expect(AlertContentFormatter.content(for: post).title == "Free food: new post")
    }

    @Test func bannerOmitsEmptyBuilding() {
        let content = AlertContent(postID: "a", title: "Free food: Pizza", body: "")
        #expect(AlertContentFormatter.bannerMessage(for: content) == "Free food: Pizza")
    }
}
