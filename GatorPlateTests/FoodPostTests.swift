import Foundation
import Testing
@testable import GatorPlate

struct FoodPostTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func post(status: PostStatus, expiresIn seconds: TimeInterval) -> FoodPost {
        var post = SampleData.post(now: now)
        post.status = status
        post.expiresAt = now.addingTimeInterval(seconds)
        return post
    }

    @Test func activeAndNotExpiredIsActive() {
        #expect(post(status: .active, expiresIn: 60).isActive(now: now))
    }

    @Test func activeButPastExpiryIsNotActive() {
        #expect(!post(status: .active, expiresIn: -1).isActive(now: now))
    }

    @Test func expiryExactlyNowIsNotActive() {
        #expect(!post(status: .active, expiresIn: 0).isActive(now: now))
    }

    @Test func oneSecondBeforeExpiryIsStillActive() {
        #expect(post(status: .active, expiresIn: 1).isActive(now: now))
    }

    @Test func expiredStatusIsNeverActive() {
        #expect(!post(status: .expired, expiresIn: 600).isActive(now: now))
    }

    @Test func goneIsNotActiveEvenBeforeExpiry() {
        #expect(!post(status: .gone, expiresIn: 600).isActive(now: now))
    }

    @Test func codableRoundTrip() throws {
        let original = SampleData.post(now: now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FoodPost.self, from: data)
        #expect(decoded == original)
    }

    @Test func allergenRawValuesAreStable() {
        #expect(Allergen.treeNuts.rawValue == "treeNuts")
        #expect(Allergen.allCases.count == 9)
    }
}
